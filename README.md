# Ridex Swift SDK

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue.svg)](https://developer.apple.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg)](LICENSE)

Route your app's AI requests through the [Ridex](https://getridex.com) gateway — automatic model routing, budget enforcement, and usage analytics with two lines of code.

---

## Requirements

iOS 16+ · macOS 13+ · Swift 5.9+ · Xcode 15+

---

## Installation

In Xcode: **File → Add Package Dependencies**, enter the URL below, and add `RidexSwiftSDK` to your target.

```
https://github.com/GetRidex/ridex-swift-sdk
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/GetRidex/ridex-swift-sdk", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["RidexSwiftSDK"])
]
```

---

## Getting Started

### Step 1 — Configure once at launch

Call `Ridex.configure()` in your app's entry point before any requests are made.

```swift
import SwiftUI
import RidexSwiftSDK

@main
struct MyApp: App {

    init() {
        Ridex.configure("rdx_live_YOUR_KEY")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

> **Good to know:** use `rdx_live_…` for production and `rdx_test_…` for development — the environment is inferred automatically.

### Step 2 — Send your first prompt

```swift
let reply = try await Ridex.prompt("Summarise this in one sentence.")
```

### Step 3 — Tag requests for analytics

Both parameters are optional.

```swift
let reply = try await Ridex.prompt(
    userInput,
    featureTag: "document-summary",   // groups by feature in analytics
    userTag:    currentUser.id        // per-user spend tracking
)
```

### Step 4 — Add a system prompt

```swift
let reply = try await Ridex.prompt(
    "Review this function for memory safety issues.",
    context: "You are a senior Swift engineer doing a security-focused code review."
)
```

### Step 5 — Handle errors

All errors are `RidexNetworkError` values:

- `.unauthorized` — invalid or expired gateway key.
- `.bundleIdMismatch` — bundle ID not allowed for this key — check your key settings in the Ridex dashboard.
- `.serverError` — gateway returned an error; `statusCode` and `message` are included.
- `.timedOut` — request timed out.
- `.cancelled` — enclosing `Task` was cancelled — no action needed.
- `.networkError` — underlying URLSession error; check `underlyingError`.
- `.invalidInput(reason)` — message was empty or too long.

---

## Demo App

The `DemoApp/` folder contains a minimal iOS chat app that demonstrates the SDK end-to-end.

1. Open `DemoApp/DemoApp.xcworkspace` in Xcode.
2. Open `DemoApp.swift` and replace `rdx_test_REPLACE_ME` with your key from [getridex.com](https://getridex.com) → API Keys.
3. Run on the simulator or a device (iOS 16+).

---

## Security

It is safe to ship your gateway key inside the app binary. Unlike raw provider keys, Ridex keys are locked to your app and budget — they can't be misused if extracted. The SDK sends all requests over HTTPS.

---

## License

Ridex Swift SDK is available under the Apache License 2.0. See [LICENSE](LICENSE) for details.
