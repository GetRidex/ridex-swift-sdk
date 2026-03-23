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

    func test_authorize_setsAuthorizationHeader() async {
        let authorized = await authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Authorization"), "Bearer \(key)")
    }

    func test_authorize_setsContentTypeHeader() async {
        let authorized = await authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_authorize_setsUserAgentHeader() async {
        let authorized = await authorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "User-Agent"), "ridex-swift/1.0.0")
    }

    // MARK: - Immutability

    func test_authorize_doesNotMutateOriginalRequest() async {
        let original = baseRequest
        _ = await authorizer.authorize(original)

        // Original should have no Authorization header.
        XCTAssertNil(original.value(forHTTPHeaderField: "Authorization"))
    }

    func test_authorize_preservesExistingURL() async {
        let url = URL(string: "https://api.getridex.com/v1/chat")!
        let request = URLRequest(url: url)
        let authorized = await authorizer.authorize(request)
        XCTAssertEqual(authorized.url, url)
    }

    func test_authorize_preservesHTTPMethod() async {
        var request = baseRequest
        request.httpMethod = "POST"
        let authorized = await authorizer.authorize(request)
        XCTAssertEqual(authorized.httpMethod, "POST")
    }

    func test_authorize_preservesBody() async {
        var request = baseRequest
        let body = #"{"key":"value"}"#.data(using: .utf8)!
        request.httpBody = body
        let authorized = await authorizer.authorize(request)
        XCTAssertEqual(authorized.httpBody, body)
    }

    // MARK: - Different keys

    func test_authorize_testKey_usesTestKeyInHeader() async {
        let testAuthorizer = RidexRequestAuthorizer(gatewayKey: "rdx_test_xyz")
        let authorized = await testAuthorizer.authorize(baseRequest)
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Authorization"), "Bearer rdx_test_xyz")
    }

    // MARK: - Device metadata headers

    func test_authorize_attachesDeviceMetadataHeaders() async {
        let authorized = await authorizer.authorize(baseRequest)
        XCTAssertNotNil(authorized.value(forHTTPHeaderField: "X-Ridex-Device-Model"))
        XCTAssertNotNil(authorized.value(forHTTPHeaderField: "X-Ridex-OS-Version"))
        XCTAssertNotNil(authorized.value(forHTTPHeaderField: "X-Ridex-App-Version"))
        XCTAssertNotNil(authorized.value(forHTTPHeaderField: "X-Ridex-Locale"))
    }

    func test_authorize_deviceMetadataHeaders_areNonEmpty() async {
        let authorized = await authorizer.authorize(baseRequest)
        XCTAssertFalse(authorized.value(forHTTPHeaderField: "X-Ridex-Device-Model")!.isEmpty)
        XCTAssertFalse(authorized.value(forHTTPHeaderField: "X-Ridex-OS-Version")!.isEmpty)
        XCTAssertFalse(authorized.value(forHTTPHeaderField: "X-Ridex-App-Version")!.isEmpty)
        XCTAssertFalse(authorized.value(forHTTPHeaderField: "X-Ridex-Locale")!.isEmpty)
    }

    // MARK: - Attest headers (no manager)

    func test_authorize_doesNotAttachAttestHeaders_whenNoManager() async {
        let auth = RidexRequestAuthorizer(gatewayKey: key, attestManager: nil)
        var request = baseRequest
        request.httpBody = Data("test-body".utf8)
        let authorized = await auth.authorize(request)
        XCTAssertNil(authorized.value(forHTTPHeaderField: "X-Ridex-Attest-Key-ID"))
        XCTAssertNil(authorized.value(forHTTPHeaderField: "X-Ridex-Attest-Assertion"))
    }

    func test_authorize_doesNotAttachAttestHeaders_whenNoBody() async {
        // Even with an AttestManager, if there's no body, no assertion headers are attached
        let mockService = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: mockService,
            baseURL: .ridexBase
        )
        let auth = RidexRequestAuthorizer(gatewayKey: key, attestManager: manager)
        // No httpBody on request
        let authorized = await auth.authorize(baseRequest)
        XCTAssertNil(authorized.value(forHTTPHeaderField: "X-Ridex-Attest-Key-ID"))
        XCTAssertNil(authorized.value(forHTTPHeaderField: "X-Ridex-Attest-Assertion"))
    }

    func test_authorize_swallowsAssertionErrors() async {
        // If the attestManager throws during assertionHeaders, authorize should still return
        let mockService = MockAppAttestService()
        mockService.generateAssertionResult = .failure(NSError(domain: "test", code: 1))
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: mockService,
            baseURL: .ridexBase
        )
        let auth = RidexRequestAuthorizer(gatewayKey: key, attestManager: manager)
        var request = baseRequest
        request.httpBody = Data("test-body".utf8)

        // This should not throw even though assertionHeaders would throw
        let authorized = await auth.authorize(request)
        // Should still have standard headers
        XCTAssertEqual(authorized.value(forHTTPHeaderField: "Authorization"), "Bearer \(key)")
    }
}
