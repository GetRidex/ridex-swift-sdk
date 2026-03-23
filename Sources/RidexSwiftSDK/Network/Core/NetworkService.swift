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

actor RidexNetworkService {

    private let session:    RidexHTTPSession
    private let authorizer: RidexRequestAuthorizer
    private var attestReady = false

    private static let retryableStatusCodes: Set<Int> = [429, 503]

    init(
        session:    RidexHTTPSession = URLSession.shared,
        authorizer: RidexRequestAuthorizer
    ) {
        self.session    = session
        self.authorizer = authorizer
    }

    func load<R: RidexDecodableResponse>(_ type: R.Type = R.self, request: URLRequest) async throws -> R {
        if !attestReady, let attestManager = authorizer.attestManager {
            do {
                try await attestManager.ensureAttested()
                attestReady = true
            } catch {}
        }

        let authorized = await authorizer.authorize(request)

        do {
            return try await execute(authorized, attempt: 1)
        } catch let error as RidexNetworkError where error == .attestRejected() {
            guard let attestManager = authorizer.attestManager else { throw error }

            await attestManager.reset()
            attestReady = false

            do {
                try await attestManager.ensureAttested()
                attestReady = true
            } catch let attestError {
                let detail = (attestError as? RidexNetworkError).flatMap { e -> String? in
                    if case .serverError(_, let msg) = e { return msg }
                    return nil
                } ?? attestError.localizedDescription
                throw RidexNetworkError.attestRejected(detail: detail)
            }

            let retryAuthorized = await authorizer.authorize(request)
            return try await execute(retryAuthorized, attempt: 1)
        }
    }

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

        let hasAttest = request.value(forHTTPHeaderField: "X-Ridex-Attest-Assertion") != nil
        if attempt == 1, !hasAttest, Self.retryableStatusCodes.contains(http.statusCode) {
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
