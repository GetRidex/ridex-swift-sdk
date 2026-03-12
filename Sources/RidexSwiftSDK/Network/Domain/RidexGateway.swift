//
//  RidexGateway.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// Internal source of truth for all Ridex gateway URLs and route paths.
///
/// All SDK code that needs a URL or path must reference this type —
/// never hard-code gateway strings elsewhere.
enum RidexGateway {

    /// Production gateway base URL.
    static let baseURL = URL(string: "https://api.getridex.com")!

    /// All API route paths, relative to ``baseURL``.
    enum Route {
        /// OpenAI-compatible chat completions endpoint.
        static let chatCompletions = "api/proxy/v1/chat/completions"
    }
}
