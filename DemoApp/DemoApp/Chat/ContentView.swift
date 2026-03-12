//
//  ContentView.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm: ChatViewModel

    init(send: @escaping (String) async throws -> String) {
        _vm = StateObject(wrappedValue: ChatViewModel(send: send))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Message list ──────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(vm.messages.enumerated()), id: \.offset) { index, msg in
                                MessageBubble(message: msg)
                                    .id(index)
                            }
                            if vm.isLoading {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: vm.isLoading) { loading in
                        if loading {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }

                // ── Error bar ─────────────────────────────────────────────
                if let err = vm.errorMessage {
                    ErrorBar(message: err) { vm.errorMessage = nil }
                }

                Divider()

                // ── Input bar ─────────────────────────────────────────────
                InputBar(
                    text:       $vm.inputText,
                    isDisabled: vm.isLoading,
                    onSend:     { Task { await vm.send() } }
                )
            }
            .navigationTitle("Ridex Demo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(vm.messages.count - 1, anchor: .bottom) }
    }
}

#Preview {
    ContentView(send: { _ in "This is a preview response." })
}
