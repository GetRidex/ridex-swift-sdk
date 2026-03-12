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

// MARK: - HTTP Session

protocol RidexHTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: RidexHTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case post = "POST"
}

// MARK: - Network Response

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
            throw RidexNetworkError.serverError(statusCode: response.statusCode, message: body?.message)
        default:
            throw RidexNetworkError.serverError(statusCode: response.statusCode, message: nil)
        }
    }
}

extension Array: RidexNetworkResponse, RidexDecodableResponse where Element: Decodable {}

// MARK: - Internal error body

/// Handles two error shapes the gateway may return:
///   OAI format    – { "error": { "message": "...", "type": "...", "code": "..." } }
///   Simple format – { "error": "bundle_id_mismatch", "message": "..." }
private struct GatewayErrorBody: Decodable {
    let message: String?
    let isBundleIdMismatch: Bool

    private enum CodingKeys: String, CodingKey { case error, message }
    private struct OAIError: Decodable { let message: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Try OAI nested object: { "error": { "message": "..." } }
        if let nested = try? c.decode(OAIError.self, forKey: .error) {
            message            = nested.message
            isBundleIdMismatch = false
        } else {
            // Simple format: { "error": "bundle_id_mismatch", "message": "..." }
            let errorCode      = try? c.decode(String.self, forKey: .error)
            message            = try? c.decode(String.self, forKey: .message)
            isBundleIdMismatch = errorCode == "bundle_id_mismatch"
        }
    }
}
