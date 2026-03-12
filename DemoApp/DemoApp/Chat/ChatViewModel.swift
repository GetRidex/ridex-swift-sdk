//
//  ChatViewModel.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages:     [ChatMessage] = []
    @Published var inputText:    String        = ""
    @Published var isLoading:    Bool          = false
    @Published var errorMessage: String?       = nil

    private let onSend: (String) async throws -> String

    init(send: @escaping (String) async throws -> String) {
        self.onSend = send
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm powered by the Ridex gateway"
        ))
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText    = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: text))
        isLoading    = true

        do {
            let reply = try await onSend(text)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
