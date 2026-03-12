//
//  Ridex.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// The Ridex namespace — your single entry point into the SDK.
///
/// Ridex routes your app's AI requests through the gateway, applying automatic model
/// selection, budget enforcement, and usage analytics on every call.
///
/// ## Setup
///
/// Call ``configure(_:)`` once at app launch — before any requests are made.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         Ridex.configure("rdx_live_...")
///     }
/// }
/// ```
///
/// ## Sending a message
///
/// Use the static ``prompt(_:context:featureTag:userTag:)`` method to send a message
/// and receive the assistant's reply as a plain `String`:
///
/// ```swift
/// let reply = try await Ridex.prompt("Explain async/await in Swift.")
/// ```
///
/// Pass an optional system prompt via `context` to guide the model's behaviour:
///
/// ```swift
/// let reply = try await Ridex.prompt(
///     "What's the weather like?",
///     context: "You are a concise weather assistant."
/// )
/// ```
///
/// ## Direct client access
///
/// For cases where you need explicit lifecycle control (e.g. multiple keys, testing),
/// access the configured instance via ``shared`` or create a standalone ``RidexClient``:
///
/// ```swift
/// let client = RidexClient("rdx_live_...")
/// let reply  = try await client.prompt("Hello")
/// ```
///
/// ## Error handling
///
/// All methods throw ``RidexNetworkError``. Handle errors with a `do/catch` block:
///
/// ```swift
/// do {
///     let reply = try await Ridex.prompt("Hello")
/// } catch let error as RidexNetworkError {
///     switch error {
///     case .unauthorized:               // invalid or expired key
///     case .invalidInput(let msg):      // invalid input
///     case .serverError(let code, _):   // gateway returned an error
///     case .timedOut:                   // request timed out
///     case .networkError:               // no connectivity
///     default: break
///     }
/// }
/// ```
public enum Ridex {

    // MARK: - Storage

    @RidexActor private static var _client: RidexClient?

    // MARK: - Configure

    /// Configures the shared Ridex client with your gateway key.
    ///
    /// Call this method **once**, at app launch, before making any requests.
    /// It is safe to call from any synchronous context, including `App.init()`.
    ///
    /// The environment is inferred automatically from the key prefix:
    /// - `rdx_live_…` → ``RidexClient/Environment/production``
    /// - `rdx_test_…` → ``RidexClient/Environment/development``
    ///
    /// Calling `configure` a second time replaces the existing client. This is
    /// intentional — useful in testing or when switching keys at runtime.
    ///
    /// - Parameter apiKey: Your Ridex gateway key. Obtain it from the
    ///   [Ridex dashboard](https://getridex.com) under **API Keys**.
    ///
    /// ```swift
    /// // App Store build
    /// Ridex.configure("rdx_live_...")
    ///
    /// // Development / TestFlight build
    /// Ridex.configure("rdx_test_...")
    /// ```
    public nonisolated static func configure(_ apiKey: String) {
        let client = RidexClient(apiKey)
        Task { @RidexActor in _client = client }
    }

    // MARK: - Shared

    /// The shared ``RidexClient`` instance configured by ``configure(_:)``.
    ///
    /// Use this property when you need direct access to the client — for example,
    /// to pass it as a dependency or call it with the same options repeatedly.
    ///
    /// For most use cases, prefer the static ``prompt(_:context:featureTag:userTag:)``
    /// method instead.
    ///
    /// - Important: Accessing this property before calling ``configure(_:)``
    ///   will crash with a descriptive error message.
    ///
    /// ```swift
    /// let client = await Ridex.shared
    /// let reply  = try await client.prompt("Hello")
    /// ```
    @RidexActor
    public static var shared: RidexClient {
        guard let client = _client else {
            fatalError(
                "[Ridex] shared accessed before configure(_:) was called. " +
                "Add Ridex.configure(\"rdx_live_…\") to your app's init or AppDelegate."
            )
        }
        return client
    }

    // MARK: - Prompt

    /// Sends a message to the Ridex gateway and returns the assistant's reply.
    ///
    /// The gateway applies automatic model routing, budget enforcement, and usage
    /// analytics on every call — no additional configuration is required.
    ///
    /// - Parameters:
    ///   - message: The user's input text. Must not be empty.
    ///   - context: An optional system prompt for the model. Use it to set a persona,
    ///     restrict the topic, or provide background knowledge. Pass `nil` to omit.
    ///   - featureTag: An optional label that groups requests by product feature
    ///     in the Ridex analytics dashboard (e.g. `"onboarding"`, `"search"`).
    ///     Pass `nil` to omit.
    ///   - userTag: An optional opaque user identifier for per-user spend tracking.
    ///     Avoid PII such as names or email addresses. Pass `nil` to omit.
    ///
    /// - Returns: The assistant's reply as a plain `String`.
    ///
    /// - Throws: ``RidexNetworkError``
    ///   - ``RidexNetworkError/invalidInput(_:)`` — `message` or `context` failed validation.
    ///   - ``RidexNetworkError/unauthorized`` — the gateway key is invalid or expired.
    ///   - ``RidexNetworkError/bundleIdMismatch`` — the app is not authorised for this key.
    ///   - ``RidexNetworkError/serverError(statusCode:message:)`` — the gateway returned an error.
    ///   - ``RidexNetworkError/timedOut`` — the request timed out.
    ///   - ``RidexNetworkError/cancelled`` — the enclosing `Task` was cancelled.
    ///   - ``RidexNetworkError/networkError(underlyingError:)`` — a network error occurred.
    ///   - ``RidexNetworkError/decodingFailed`` — the gateway response could not be parsed.
    ///
    /// ```swift
    /// // Basic usage
    /// let reply = try await Ridex.prompt("What is the capital of France?")
    ///
    /// // With a system prompt
    /// let reply = try await Ridex.prompt(
    ///     "Summarise this in one sentence.",
    ///     context: "You are a concise summarisation assistant."
    /// )
    ///
    /// // With analytics tags
    /// let reply = try await Ridex.prompt(
    ///     userMessage,
    ///     featureTag: "chat",
    ///     userTag:    currentUser.id
    /// )
    /// ```
    @RidexActor
    public static func prompt(
        _ message:  String,
        context:    String? = nil,
        featureTag: String? = nil,
        userTag:    String? = nil
    ) async throws -> String {
        try await shared.prompt(message, context: context, featureTag: featureTag, userTag: userTag)
    }
}
