//
//  ChatRequest.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

struct ChatRequest: Encodable {
    let messages: [Message]

    init(messages: [Message]) {
        self.messages = messages
    }
}
