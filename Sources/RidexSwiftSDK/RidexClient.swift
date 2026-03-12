//
//  RidexClient.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// A configured Ridex gateway client.
///
/// `RidexClient` sends authenticated requests to the Ridex gateway and returns
/// the assistant's reply as a plain `String`. The gateway handles model selection,
/// budget enforcement, and usage analytics automatically.
///
/// ## Recommended usage
///
/// For most apps, use the shared singleton via ``Ridex/configure(_:)`` at launch
/// and call ``Ridex/prompt(_:context:featureTag:userTag:)`` directly — you never
/// need to interact with `RidexClient` directly.
///
/// ```swift
/// Ridex.configure("rdx_live_...")
/// let reply = try await Ridex.prompt("Hello")
/// ```
///
/// ## Direct instantiation
///
/// Create a `RidexClient` directly when you need explicit lifecycle control —
/// for example, when supporting multiple gateway keys or injecting it as a dependency:
///
/// ```swift
/// final class MyFeatureViewModel: ObservableObject {
///     private let ridex = RidexClient("rdx_live_...")
///
///     func ask(_ question: String) async throws -> String {
///         try await ridex.prompt(question, featureTag: "my-feature")
///     }
/// }
/// ```
///
/// ## Thread safety
///
/// `RidexClient` is `Sendable` and can be shared freely across actors and threads.
/// Concurrent calls to ``prompt(_:context:featureTag:userTag:)`` are fully supported.
public final class RidexClient: Sendable {

    // MARK: - Internal state

    let env:            Environment
    let networkService: RidexNetworkService
    let requestFactory: RidexRequestFactory

    // MARK: - Constants

    private static let maxMessageLength = 32_000
    private static let maxTagLength = 128

    // MARK: - Init

    /// Creates a new Ridex client with the given gateway key.
    ///
    /// The environment is inferred automatically from the key prefix:
    /// - `rdx_live_…` → ``Environment/production``
    /// - `rdx_test_…` → ``Environment/development``
    ///
    /// - Parameter apiKey: Your Ridex gateway key. Obtain it from the
    ///   [Ridex dashboard](https://getridex.com) under **API Keys**.
    ///
    /// ```swift
    /// let client = RidexClient("rdx_live_...")
    /// ```
    public init(_ apiKey: String) {
        let inferredEnv = Environment.inferred(from: apiKey)
        self.env = inferredEnv

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest  = 60
        sessionConfig.timeoutIntervalForResource = 120

        self.networkService = RidexNetworkService(
            session:    URLSession(configuration: sessionConfig),
            authorizer: RidexRequestAuthorizer(gatewayKey: apiKey)
        )
        self.requestFactory = RidexRequestFactory()
    }

    // MARK: - Init (testable)

    init(apiKey: String, networkService: RidexNetworkService) {
        self.env            = Environment.inferred(from: apiKey)
        self.networkService = networkService
        self.requestFactory = RidexRequestFactory()
    }

    // MARK: - Internal request builder

    func buildRequest(
        api:        RidexAPI,
        body:       some Encodable,
        featureTag: String? = nil,
        userTag:    String? = nil
    ) throws -> URLRequest {
        var request = try requestFactory.make(for: api, body: body)
        request.setValue(env.rawValue, forHTTPHeaderField: "X-Ridex-Env")
        if let bundleId = Bundle(for: RidexClient.self).bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Ridex-Bundle-ID")
        }
        if let tag = featureTag.flatMap(sanitized) { request.setValue(tag, forHTTPHeaderField: "X-Ridex-Feature") }
        if let uid = userTag.flatMap(sanitized)    { request.setValue(uid, forHTTPHeaderField: "X-Ridex-User-ID") }
        return request
    }

    // MARK: - Prompt

    /// Sends a message to the Ridex gateway and returns the assistant's reply.
    ///
    /// - Parameters:
    ///   - message: The user's input text. Must not be empty.
    ///     Throws ``RidexNetworkError/invalidInput(_:)`` if validation fails.
    ///   - context: An optional system prompt that guides the model's behaviour —
    ///     use it to set a persona, restrict the topic, or provide background knowledge.
    ///     Pass `nil` (default) to omit.
    ///   - featureTag: An optional label that groups requests by product feature
    ///     in the Ridex analytics dashboard (e.g. `"onboarding"`, `"search"`).
    ///     Pass `nil` (default) to omit.
    ///   - userTag: An optional opaque user identifier for per-user spend tracking
    ///     in the dashboard. Avoid PII such as names or email addresses.
    ///     Pass `nil` (default) to omit.
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
    /// // Basic
    /// let reply = try await client.prompt("What is the capital of France?")
    ///
    /// // With system prompt
    /// let reply = try await client.prompt(
    ///     "Summarise this in one sentence.",
    ///     context: "You are a concise summarisation assistant."
    /// )
    ///
    /// // With analytics tags
    /// let reply = try await client.prompt(
    ///     userMessage,
    ///     featureTag: "chat",
    ///     userTag:    currentUser.id
    /// )
    /// ```
    public func prompt(
        _ message:  String,
        context:    String? = nil,
        featureTag: String? = nil,
        userTag:    String? = nil
    ) async throws -> String {
        guard !message.isEmpty else {
            throw RidexNetworkError.invalidInput("Message must not be empty.")
        }
        guard message.count <= Self.maxMessageLength else {
            throw RidexNetworkError.invalidInput("Message is too long.")
        }
        if let context {
            guard context.count <= Self.maxMessageLength else {
                throw RidexNetworkError.invalidInput("Context is too long.")
            }
        }

        var messages: [Message] = []
        if let context { messages.append(.system(context)) }
        messages.append(.user(message))
        let body    = ChatRequest(messages: messages)
        let request = try buildRequest(api: .chat, body: body,
                                       featureTag: featureTag, userTag: userTag)
        return try await networkService.load(ChatResponse.self, request: request).text
    }

    // MARK: - Private helpers

    private func sanitized(_ tag: String) -> String? {
        let cleaned = tag.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .reduce(into: "") { $0 += String($1) }
        let truncated = String(cleaned.prefix(Self.maxTagLength))
        return truncated.isEmpty ? nil : truncated
    }
}
