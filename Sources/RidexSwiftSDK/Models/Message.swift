//
//  Message.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

struct Message: Codable, Sendable {
    let role:    Role
    let content: String

    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }

    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }
}
