//
//  DemoApp.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI
import RidexSwiftSDK

@main
struct DemoApp: App {

    // ── Step 1: Configure ─────────────────────────────────────────────────
    //
    // Call Ridex.configure(_:) once at app launch with your gateway key.
    // The environment is inferred automatically from the key prefix:
    //   rdx_live_…  → production
    //   rdx_test_…  → development
    //
    // Get your key at https://api.getridex.com → API Keys.
    //   rdx_live_…   Production key
    //   rdx_test_…   Test key — safe for simulator and TestFlight
    //
    private let apiKey: String = "rdx_test_REPLACE_ME"

    // Sent as X-Feature-Tag on every request.
    // Groups requests by feature in the Ridex analytics dashboard.
    // Examples: "onboarding", "chat", "search" — set nil to omit.
    private let featureTag: String? = "ridex-demo"

    // Sent as X-User-Tag on every request.
    // Tracks per-user spend in the dashboard.
    // Use an opaque ID — avoid PII. Set nil to omit.
    private let userTag: String? = nil

    init() {
        Ridex.configure(apiKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(send: sendMessage)
        }
    }

    // ── Step 2: Send a message ─────────────────────────────────────────────
    //
    // Ridex.prompt(_:context:featureTag:userTag:) is the main SDK method.
    // The gateway applies model routing, budget caps, and usage analytics
    // automatically on every call — no extra code needed on your side.
    //
    // Parameters:
    //   message    — the user's input
    //   context    — optional system prompt prepended to the conversation
    //   featureTag — optional feature label for dashboard grouping
    //   userTag    — optional user ID for per-user spend tracking
    //
    // Returns a ChatResponse with:
    //   .text  — the assistant's reply
    //
    // Throws RidexNetworkError — see NetworkServiceError.swift for all cases.
    //
    private func sendMessage(_ text: String) async throws -> String {
        return try await Ridex.prompt(
            text,
            featureTag: featureTag,
            userTag:    userTag
        )
    }
}
