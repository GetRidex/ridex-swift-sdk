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

struct RidexRequestAuthorizer {

    private let gatewayKey: String
    let attestManager: AttestManager?

    init(gatewayKey: String, attestManager: AttestManager? = nil) {
        self.gatewayKey = gatewayKey
        self.attestManager = attestManager
    }

    func authorize(_ request: URLRequest) async -> URLRequest {
        var r = request
        r.setValue("Bearer \(gatewayKey)", forHTTPHeaderField: HTTPHeaderName.authorization.rawValue)
        r.setValue("ridex-swift/1.0.0", forHTTPHeaderField: HTTPHeaderName.userAgent.rawValue)
        r.setValue("application/json", forHTTPHeaderField: HTTPHeaderName.contentType.rawValue)

        for (key, value) in DeviceInfo.headers {
            r.setValue(value, forHTTPHeaderField: key)
        }

        if let attestManager, let body = request.httpBody {
            do {
                let headers = try await attestManager.assertionHeaders(for: body)
                for (key, value) in headers { r.setValue(value, forHTTPHeaderField: key) }
            } catch {}
        }

        return r
    }
}
