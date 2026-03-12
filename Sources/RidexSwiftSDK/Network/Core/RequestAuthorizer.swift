//
//  RequestAuthorizer.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// Attaches the Ridex gateway key and standard headers to every outgoing request.
struct RidexRequestAuthorizer {

    private let gatewayKey: String

    init(gatewayKey: String) {
        self.gatewayKey = gatewayKey
    }

    /// Returns a copy of the request with `Authorization` and `User-Agent` attached.
    func authorize(_ request: URLRequest) -> URLRequest {
        var r = request
        r.setValue("Bearer \(gatewayKey)", forHTTPHeaderField: HTTPHeaderName.authorization.rawValue)
        r.setValue("ridex-swift/1.0.0", forHTTPHeaderField: HTTPHeaderName.userAgent.rawValue)
        r.setValue("application/json", forHTTPHeaderField: HTTPHeaderName.contentType.rawValue)
        return r
    }
}
