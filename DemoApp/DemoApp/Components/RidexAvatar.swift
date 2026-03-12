//
//  RidexAvatar.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

/// The Ridex "R" brand mark used as the assistant avatar.
struct RidexAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.40, blue: 0.98),  // Ridex blue
                            Color(red: 0.42, green: 0.18, blue: 0.96)   // Ridex violet
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            Text("R")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
