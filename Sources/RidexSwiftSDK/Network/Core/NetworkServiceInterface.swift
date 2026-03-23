//
//  NetworkServiceInterface.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

protocol RidexHTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: RidexHTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

enum HTTPMethod: String {
    case post = "POST"
}

protocol RidexNetworkResponse {
    init(response: HTTPURLResponse, data: Data?) throws
}

protocol RidexDecodableResponse: RidexNetworkResponse {
    init(decoding data: Data) throws
}

extension RidexDecodableResponse where Self: Decodable {
    init(decoding data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

extension RidexDecodableResponse {
    init(response: HTTPURLResponse, data: Data?) throws {
        switch response.statusCode {
        case 200...299:
            guard let data, !data.isEmpty else { throw RidexNetworkError.decodingFailed }
            do {
                try self.init(decoding: data)
            } catch {
                throw RidexNetworkError.decodingFailed
            }
        case 400...599:
            let body = data.flatMap { try? JSONDecoder().decode(GatewayErrorBody.self, from: $0) }
            if response.statusCode == 401 {
                throw RidexNetworkError.unauthorized
            }
            if response.statusCode == 403, body?.isBundleIdMismatch == true {
                throw RidexNetworkError.bundleIdMismatch
            }
            if response.statusCode == 403, body?.isDeviceRevoked == true {
                throw RidexNetworkError.serverError(statusCode: 403, message: "This device has been revoked.")
            }
            if response.statusCode == 403, body?.isAttestError == true {
                throw RidexNetworkError.attestRejected(detail: body?.message)
            }
            throw RidexNetworkError.serverError(statusCode: response.statusCode, message: body?.message)
        default:
            throw RidexNetworkError.serverError(statusCode: response.statusCode, message: nil)
        }
    }
}

extension Array: RidexNetworkResponse, RidexDecodableResponse where Element: Decodable {}

struct GatewayErrorBody: Decodable {
    let message: String?
    let code: String?
    let isBundleIdMismatch: Bool

    var isAttestError: Bool {
        switch code {
        case "attest_required", "device_unknown", "invalid_assertion":
            return true
        default:
            return false
        }
    }

    var isDeviceRevoked: Bool {
        code == "device_revoked"
    }

    private enum CodingKeys: String, CodingKey { case error, message }
    private struct OAIError: Decodable { let message: String?; let code: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try? c.decode(OAIError.self, forKey: .error) {
            message            = nested.message
            code               = nested.code
            isBundleIdMismatch = false
        } else {
            let errorCode      = try? c.decode(String.self, forKey: .error)
            message            = try? c.decode(String.self, forKey: .message)
            code               = errorCode
            isBundleIdMismatch = errorCode == "bundle_id_mismatch"
        }
    }
}
