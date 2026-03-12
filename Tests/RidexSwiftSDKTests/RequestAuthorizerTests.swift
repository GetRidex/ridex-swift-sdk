import XCTest
@testable import RidexSwiftSDK

// MARK: - RequestAuthorizerTests

/// Tests for `RidexRequestAuthorizer`.
///
/// Verifies that the correct headers are attached and that the original
/// request is not mutated (authorizer returns a copy).
final class RequestAuthorizerTests: XCTestCase {

    private let key        = "rdx_live_test_key_abc"
    private var authorizer: RidexRequestAuthorizer { RidexRequestAuthorizer(gatewayKey: key) }
    private var baseRequest: URLRequest             { URLRequest(url: .ridexBase) }

    // MARK: - Header values

    func test_authorize_setsAuthorizationHeader() {
        let authorized = authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Authorization"), "Bearer \(key)")
    }

    func test_authorize_setsContentTypeHeader() {
        let authorized = authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_authorize_setsUserAgentHeader() {
        let authorized = authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "User-Agent"), "ridex-swift/1.0.0")
    }

    // MARK: - Immutability

    func test_authorize_doesNotMutateOriginalRequest() {
        let original = baseRequest
        _ = authorizer.authorize(original)

        // Original should have no Authorization header.
        XCTAssertNil(original.value(forHTTPHeaderField: "Authorization"))
    }

    func test_authorize_preservesExistingURL() {
        let url = URL(string: "https://api.getridex.com/v1/chat")!
        let request = URLRequest(url: url)
        let authorized = authorizer.authorize(request)
        XCTAssertEqual(authorized.url, url)
    }

    func test_authorize_preservesHTTPMethod() {
        var request = baseRequest
        request.httpMethod = "POST"
        let authorized = authorizer.authorize(request)
        XCTAssertEqual(authorized.httpMethod, "POST")
    }

    func test_authorize_preservesBody() {
        var request = baseRequest
        let body = #"{"key":"value"}"#.data(using: .utf8)!
        request.httpBody = body
        let authorized = authorizer.authorize(request)
        XCTAssertEqual(authorized.httpBody, body)
    }

    // MARK: - Different keys

    func test_authorize_testKey_usesTestKeyInHeader() {
        let testAuthorizer = RidexRequestAuthorizer(gatewayKey: "rdx_test_xyz")
        let authorized = testAuthorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Authorization"), "Bearer rdx_test_xyz")
    }
}
