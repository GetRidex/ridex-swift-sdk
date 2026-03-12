//
//  UserCredentialStorageProvider.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

// MARK: - HTTP Header Name

struct HTTPHeaderName: RawRepresentable, Equatable, Hashable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
}

extension HTTPHeaderName {
    static let authorization = HTTPHeaderName(rawValue: "Authorization")
    static let contentType   = HTTPHeaderName(rawValue: "Content-Type")
    static let userAgent     = HTTPHeaderName(rawValue: "User-Agent")
}

// MARK: - URLRequest helpers

extension URLRequest {
    init(_ method: HTTPMethod, url: URL, body: Data? = nil) {
        self.init(url: url)
        httpMethod = method.rawValue
        httpBody = body
    }
}
