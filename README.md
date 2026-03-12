# Ridex Swift SDK

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue.svg)](https://developer.apple.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg)](LICENSE)

The Ridex Swift SDK makes it quick and easy to route your app's AI requests through the [Ridex](https://getridex.com) gateway — getting automatic model routing, budget enforcement, and real-time usage analytics with two lines of code.

---

## What is Ridex?

Ridex is an AI infrastructure control plane for product teams. Instead of calling model providers directly, your app sends requests through the Ridex gateway, which:

- **Routes intelligently** — picks the fastest, cheapest, or most capable model based on your configured strategy, traffic patterns, and provider health.
- **Enforces budgets** — hard-caps spend per project, feature, or user so a runaway feature never blows your monthly bill.
- **Tracks analytics** — logs every request with latency, token counts, cost, and model used, broken down by feature and user — without your app sending any telemetry code.
- **Handles failover** — falls back to secondary providers automatically when a primary is degraded, with no changes to your app code.

The SDK handles everything between your call and the gateway. You own the product; Ridex owns the infrastructure.

---

## Requirements

| | Minimum |
|---|---|
| iOS | 16.0 |
| macOS | 13.0 |
| Swift | 5.9 |
| Xcode | 15.0 |

---

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**, enter the repository URL, and add `RidexSwiftSDK` to your target.

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ridex/ridex-swift-sdk", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["RidexSwiftSDK"])
]
```

---

## Getting Started

**Step 1 — Configure once at app launch:**

```swift
import RidexSwiftSDK

@main
struct MyApp: App {
    init() {
        Ridex.configure("rdx_live_YOUR_KEY")
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

**Step 2 — Send a prompt:**

```swift
let reply = try await Ridex.prompt("Summarise this article in three bullet points.")
print(reply)
```

The gateway applies your routing strategy, budget cap, and analytics automatically on every call.

---

## API Reference

### `Ridex.configure(_:)`

Configures the SDK with your gateway key. Call this **once**, before any `prompt()` calls — typically in `App.init()` or `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.

```swift
static func configure(_ apiKey: String)
```

| Parameter | Type | Description |
|---|---|---|
| `apiKey` | `String` | Your Ridex gateway key. Get it from [getridex.com](https://getridex.com) → API Keys. |

The environment is inferred automatically from the key prefix — `rdx_live_…` maps to production, `rdx_test_…` maps to development. Calling `configure(_:)` a second time replaces the previous configuration.

```swift
// App Store build
Ridex.configure("rdx_live_...")

// Development / TestFlight
Ridex.configure("rdx_test_...")
```

---

### `Ridex.prompt(_:context:featureTag:userTag:)`

Sends a message to the gateway and returns the assistant's reply as a plain `String`.

```swift
static func prompt(
    _ message:  String,
    context:    String? = nil,
    featureTag: String? = nil,
    userTag:    String? = nil
) async throws -> String
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `message` | `String` | — | The user's input. Must be non-empty. |
| `context` | `String?` | `nil` | Optional system prompt for the model. Sets its persona, topic, or task framing. |
| `featureTag` | `String?` | `nil` | Groups requests by feature in the analytics dashboard (e.g. `"onboarding"`, `"search"`). |
| `userTag` | `String?` | `nil` | Tracks per-user spend in the dashboard. Use an opaque ID — avoid PII. |

**Returns:** `String` — the assistant's reply.

**Throws:** `RidexNetworkError` — see [Error Handling](#error-handling).

```swift
// Basic
let reply = try await Ridex.prompt("What year did the Berlin Wall fall?")

// With a system prompt
let reply = try await Ridex.prompt(
    "Review this Swift function for memory safety issues.",
    context: "You are a senior Swift engineer doing a security-focused code review."
)

// With analytics tags
let reply = try await Ridex.prompt(
    userInput,
    featureTag: "document-summary",
    userTag:    currentUser.id
)
```

---

### `Ridex.shared`

Returns the shared `RidexClient` created by `configure(_:)`. Crashes with a descriptive `fatalError` if accessed before `configure(_:)` is called.

```swift
static var shared: RidexClient { get }
```

```swift
// Check the active environment
print(await Ridex.shared.env)  // .production or .development
```

For most use cases, call `Ridex.prompt(...)` directly.

---

### `RidexClient`

The underlying gateway client. Most apps never instantiate this directly — use `Ridex.configure(_:)` and `Ridex.prompt(...)` instead.

Create a standalone instance when you need explicit lifecycle control — for example, multiple keys or dependency injection:

```swift
final class MyViewModel: ObservableObject {
    private let ridex = RidexClient("rdx_live_...")

    func ask(_ question: String) async throws -> String {
        try await ridex.prompt(question, featureTag: "my-feature")
    }
}
```

#### Initialiser

```swift
init(_ apiKey: String)
```

#### `prompt(_:context:featureTag:userTag:)`

Instance equivalent of `Ridex.prompt(...)`. Same parameters, same return type.

```swift
func prompt(
    _ message:  String,
    context:    String? = nil,
    featureTag: String? = nil,
    userTag:    String? = nil
) async throws -> String
```

#### `env`

```swift
var env: RidexClient.Environment { get }
```

The environment this client operates in — inferred from the key prefix or set explicitly.

---

### `RidexClient.Environment`

```swift
public enum Environment {
    case production
    case development
}
```

| Case | Key prefix | Use for |
|---|---|---|
| `.production` | `rdx_live_…` | App Store and production deployments |
| `.development` | `rdx_test_…` | Simulator, TestFlight, CI, local dev |

The gateway applies separate routing rules and analytics namespaces for each environment.

---

## Error Handling

All errors thrown by `prompt()` are `RidexNetworkError` values. Match on specific cases to handle each situation:

```swift
public enum RidexNetworkError: Error {
    case invalidInput(_ reason: String)
    case unauthorized
    case bundleIdMismatch
    case serverError(statusCode: Int, message: String?)
    case decodingFailed
    case invalidResponse
    case networkError(underlyingError: Error)
    case timedOut
    case cancelled
}
```

| Case | When it occurs |
|---|---|
| `.invalidInput(reason)` | `message` is empty or exceeds the allowed length. `reason` describes the specific constraint. |
| `.unauthorized` | The gateway key is invalid, expired, or revoked. |
| `.bundleIdMismatch` | The app is not authorised for this key — check the key's configuration in the Ridex dashboard. |
| `.serverError(statusCode, message)` | The gateway returned an error. `statusCode` and `message` contain details. |
| `.decodingFailed` | The gateway response couldn't be parsed. Try updating the SDK. |
| `.invalidResponse` | An unexpected response was received. |
| `.networkError(underlyingError)` | A network error occurred. Check `underlyingError` for details. |
| `.timedOut` | The request timed out. |
| `.cancelled` | The enclosing `Task` was cancelled. |

All `RidexNetworkError` values conform to `LocalizedError` — `error.localizedDescription` returns a human-readable message suitable for logs.


```swift
do {
    let reply = try await Ridex.prompt(userMessage, featureTag: "chat")
    display(reply)
} catch let error as RidexNetworkError {
    switch error {
    case .invalidInput(let reason):
        showAlert(reason)
    case .unauthorized:
        showAlert("Invalid API key — check your key in the Ridex dashboard.")
    case .serverError(_, let message):
        showAlert(message ?? "A server error occurred. Please try again.")
    case .timedOut:
        showAlert("The request timed out. Please try again.")
    case .cancelled:
        break  // user navigated away — no action needed
    default:
        showAlert("Something went wrong: \(error.localizedDescription)")
    }
} catch {
    showAlert(error.localizedDescription)
}
```

---

## Demo App

The `DemoApp/` folder contains a minimal iOS chat app that demonstrates the SDK end-to-end.

**Running the demo:**

1. Open `DemoApp/DemoApp.xcworkspace` in Xcode.
2. Open `DemoApp.swift` and replace `rdx_test_REPLACE_ME` with your key from [getridex.com](https://getridex.com) → API Keys.
3. Run on the simulator or a device (iOS 16+).

All SDK configuration — API key, feature tag, and user tag — is declared at the top of `DemoApp.swift`.

---

## Security

Ridex gateway keys are designed to be shipped inside your app binary — this is intentional. Unlike raw model provider keys (OpenAI, Anthropic, etc.), the gateway enforces access controls and budget caps on every request. A key extracted from your binary cannot be used outside the context it was issued for.

Use `rdx_test_…` keys during development to keep test traffic out of your production analytics. Switch to `rdx_live_…` for App Store and production builds.

- The SDK sends all requests over HTTPS.

---

## License

Ridex Swift SDK is available under the Apache License 2.0. See [LICENSE](LICENSE) for details.
