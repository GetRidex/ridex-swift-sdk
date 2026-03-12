//
//  TypingIndicator.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

/// Three animated dots shown while the gateway is processing the request.
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        BubbleLayout(isUser: false) {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == i ? 1.4 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .onAppear { phase = 1 }
    }
}
