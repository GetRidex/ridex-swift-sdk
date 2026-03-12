//
//  RequestFactory.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// Builds `URLRequest` instances for the Ridex gateway API.
struct RidexRequestFactory: Sendable {

    func make(for api: RidexAPI, body: (any Encodable)? = nil) throws -> URLRequest {
        let url = RidexGateway.baseURL.appendingPathComponent(api.path)
        var request = URLRequest(api.method, url: url)
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }
}
