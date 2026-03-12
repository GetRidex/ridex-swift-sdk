//
//  BubbleLayout.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

/// Shared horizontal layout — user messages on the right, assistant on the left.
struct BubbleLayout<Content: View>: View {
    let isUser: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            // Ridex avatar — displayed next to assistant messages.
            if !isUser { RidexAvatar() }

            content()

            if !isUser { Spacer(minLength: 60) }

            // User avatar — displayed next to user messages.
            if isUser {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
        }
    }
}
