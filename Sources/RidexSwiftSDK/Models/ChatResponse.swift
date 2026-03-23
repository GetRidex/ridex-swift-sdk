//
//  ChatResponse.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

struct ChatResponse {
    let text: String
}

extension ChatResponse: Decodable {

    private struct Choice: Decodable {
        struct AssistantMessage: Decodable { let content: String }
        let message: AssistantMessage
    }

    private enum CodingKeys: String, CodingKey {
        case choices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let choices   = try container.decode([Choice].self, forKey: .choices)
        self.text     = choices.first?.message.content ?? ""
    }
}

extension ChatResponse: RidexDecodableResponse {}
