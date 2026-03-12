//
//  InputBar.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

/// Text field and send button at the bottom of the screen.
struct InputBar: View {
    @Binding var text: String
    var isDisabled: Bool
    var onSend:     () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .disabled(isDisabled)
                .onSubmit { if !isDisabled { onSend() } }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(text.isEmpty || isDisabled ? .secondary : .blue)
            }
            .disabled(text.isEmpty || isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}
