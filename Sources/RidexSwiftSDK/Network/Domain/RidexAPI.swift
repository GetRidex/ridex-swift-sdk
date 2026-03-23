//
//  RidexAPI.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// All Ridex gateway API endpoints.
enum RidexAPI {

    /// Sends a message and returns the full text response.
    case chat

    var path: String {
        switch self {
        case .chat: return RidexGateway.Route.chatCompletions
        }
    }

    var method: HTTPMethod {
        switch self {
        case .chat: return .post
        }
    }
}
