//
//  ChatMessage.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. MIT License.
//

import Foundation

/// A single message in the demo chat history.
struct ChatMessage {
    let role:    Role
    let content: String

    enum Role { case user, assistant }
}
