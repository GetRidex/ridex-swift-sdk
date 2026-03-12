import Foundation
@testable import RidexSwiftSDK

/// Configurable test double for `RidexHTTPSession`.
///
/// Set `dataError` to simulate network failures.
/// Set `dataResult` for a single fixed response.
/// Set `dataResults` for a sequence of responses (consumed in order; last is reused if exhausted).
final class MockHTTPSession: RidexHTTPSession {

    // MARK: - Stubs

    /// When set, `data(for:)` throws this error instead of returning a result.
    var dataError: Error?

    /// Returned by `data(for:)` when `dataResults` is empty. Defaults to an empty 200 response.
    var dataResult: (Data, URLResponse) = (Data(), MockHTTPSession.http(200))

    /// Sequential results consumed one-by-one. Useful for testing retry behaviour.
    /// When exhausted, falls back to `dataResult`.
    var dataResults: [(Data, URLResponse)] = []

    // MARK: - Captured requests

    private(set) var capturedDataRequests: [URLRequest] = []

    // MARK: - RidexHTTPSession

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedDataRequests.append(request)
        if let error = dataError { throw error }
        if !dataResults.isEmpty { return dataResults.removeFirst() }
        return dataResult
    }
}

// MARK: - Helpers

extension MockHTTPSession {

    static func http(_ statusCode: Int, url: URL = .ridexBase, headers: [String: String]? = nil) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
    }
}

extension URL {
    static let ridexBase = URL(string: "https://api.getridex.com")!
}
