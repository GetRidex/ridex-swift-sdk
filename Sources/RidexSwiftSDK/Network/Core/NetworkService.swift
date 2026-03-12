//
//  NetworkService.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// The Ridex network layer. Executes authenticated HTTP requests using structured concurrency.
actor RidexNetworkService {

    private let session:    RidexHTTPSession
    private let authorizer: RidexRequestAuthorizer

    private static let retryableStatusCodes: Set<Int> = [429, 503]

    init(
        session:    RidexHTTPSession = URLSession.shared,
        authorizer: RidexRequestAuthorizer
    ) {
        self.session    = session
        self.authorizer = authorizer
    }

    // MARK: – Load

    func load<R: RidexDecodableResponse>(_ type: R.Type = R.self, request: URLRequest) async throws -> R {
        let authorized = authorizer.authorize(request)
        return try await execute(authorized, attempt: 1)
    }

    // MARK: – Private

    private func execute<R: RidexDecodableResponse>(_ request: URLRequest, attempt: Int) async throws -> R {
        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw map(urlError)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw RidexNetworkError.invalidResponse
        }

        if attempt == 1, Self.retryableStatusCodes.contains(http.statusCode) {
            let delay = retryDelay(from: http)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await execute(request, attempt: 2)
        }

        return try R(response: http, data: data)
    }

    private func retryDelay(from response: HTTPURLResponse) -> Double {
        if let value   = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(value) {
            return min(seconds, 5.0)
        }
        return 1.0
    }

    private func map(_ urlError: URLError) -> RidexNetworkError {
        switch urlError.code {
        case .cancelled: return .cancelled
        case .timedOut:  return .timedOut
        default:         return .networkError(underlyingError: urlError)
        }
    }
}
