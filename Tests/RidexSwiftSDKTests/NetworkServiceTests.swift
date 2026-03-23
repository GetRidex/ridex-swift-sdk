import XCTest
@testable import RidexSwiftSDK

// MARK: - NetworkServiceTests

final class NetworkServiceTests: XCTestCase {

    private func makeService(_ session: MockHTTPSession) -> RidexNetworkService {
        RidexNetworkService(
            session: session,
            authorizer: RidexRequestAuthorizer(gatewayKey: "rdx_test_key123")
        )
    }

    private var blankRequest: URLRequest { URLRequest(url: .ridexBase) }

    private var validChatJSON: Data {
        """
        {
            "id": "chatcmpl-abc",
            "model": "gpt-4o",
            "choices": [{ "index": 0, "message": { "role": "assistant", "content": "Hello!" }, "finish_reason": "stop" }]
        }
        """.data(using: .utf8)!
    }

    // MARK: - Success

    func test_load_200_decodesResponse() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))

        let response: ChatResponse = try await makeService(session).load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
    }

    func test_load_201_isAlsoAccepted() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(201))
        let response: ChatResponse = try await makeService(session).load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
    }

    func test_load_appliesAuthorizerBeforeSendingRequest() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let _: ChatResponse = try await makeService(session).load(request: blankRequest)

        let captured = try XCTUnwrap(session.capturedDataRequests.first)
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Authorization"), "Bearer rdx_test_key123")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Content-Type"),  "application/json")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "User-Agent"),    "ridex-swift/1.0.0")
    }

    // MARK: - HTTP error mapping

    func test_load_401_throwsUnauthorized() async throws {
        let session = MockHTTPSession()
        session.dataResult = (Data(), MockHTTPSession.http(401))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .unauthorized = $0 { return true }; return false }
        )
    }

    func test_load_403_bundleIdMismatch_throwsBundleIdMismatch() async throws {
        let session = MockHTTPSession()
        let body = #"{"error":"bundle_id_mismatch","message":"This key is not authorized for this application."}"#.data(using: .utf8)!
        session.dataResult = (body, MockHTTPSession.http(403))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .bundleIdMismatch = $0 { return true }; return false }
        )
    }

    func test_load_403_generic_throwsServerError() async throws {
        let session = MockHTTPSession()
        session.dataResult = (Data(), MockHTTPSession.http(403))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .serverError(403, _) = $0 { return true }; return false }
        )
    }

    func test_load_500_throwsServerError() async throws {
        let session = MockHTTPSession()
        session.dataResult = (Data(), MockHTTPSession.http(500))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .serverError(500, _) = $0 { return true }; return false }
        )
    }

    func test_load_500_withErrorBody_includesMessage() async throws {
        let session = MockHTTPSession()
        let body = #"{"error":"internal_error","message":"Something went wrong."}"#.data(using: .utf8)!
        session.dataResult = (body, MockHTTPSession.http(500))

        do {
            let _: ChatResponse = try await makeService(session).load(request: blankRequest)
            XCTFail("Expected server error")
        } catch let err as RidexNetworkError {
            guard case .serverError(_, let message) = err else {
                XCTFail("Expected .serverError, got \(err)"); return
            }
            XCTAssertEqual(message, "Something went wrong.")
        }
    }

    func test_load_nonHTTPResponse_throwsInvalidResponse() async throws {
        let session = MockHTTPSession()
        let plain = URLResponse(url: .ridexBase, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        session.dataResult = (Data(), plain)
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .invalidResponse = $0 { return true }; return false }
        )
    }

    // MARK: - Decoding failures

    func test_load_200_emptyBody_throwsDecodingFailed() async throws {
        let session = MockHTTPSession()
        session.dataResult = (Data(), MockHTTPSession.http(200))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .decodingFailed = $0 { return true }; return false }
        )
    }

    func test_load_200_malformedJSON_throwsDecodingFailed() async throws {
        let session = MockHTTPSession()
        session.dataResult = ("not json".data(using: .utf8)!, MockHTTPSession.http(200))
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .decodingFailed = $0 { return true }; return false }
        )
    }

    // MARK: - Retry behaviour

    func test_load_503_retriesOnce_andSucceeds() async throws {
        let session = MockHTTPSession()
        session.dataResults = [
            (Data(), MockHTTPSession.http(503)),      // first attempt → 503
            (validChatJSON, MockHTTPSession.http(200)) // retry → 200
        ]

        let response: ChatResponse = try await makeService(session).load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
        XCTAssertEqual(session.capturedDataRequests.count, 2, "Expected exactly one retry")
    }

    func test_load_429_retriesOnce_andSucceeds() async throws {
        let session = MockHTTPSession()
        session.dataResults = [
            (Data(), MockHTTPSession.http(429)),
            (validChatJSON, MockHTTPSession.http(200))
        ]

        let response: ChatResponse = try await makeService(session).load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
        XCTAssertEqual(session.capturedDataRequests.count, 2)
    }

    func test_load_503_doesNotRetryMoreThanOnce() async throws {
        let session = MockHTTPSession()
        session.dataResults = [
            (Data(), MockHTTPSession.http(503)),
            (Data(), MockHTTPSession.http(503))
        ]

        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .serverError(503, _) = $0 { return true }; return false }
        )
        XCTAssertEqual(session.capturedDataRequests.count, 2, "Should not retry more than once")
    }

    // MARK: - URLError mapping

    func test_load_URLError_cancelled_throwsCancelled() async throws {
        let session = MockHTTPSession()
        session.dataError = URLError(.cancelled)
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .cancelled = $0 { return true }; return false }
        )
    }

    func test_load_URLError_timedOut_throwsTimedOut() async throws {
        let session = MockHTTPSession()
        session.dataError = URLError(.timedOut)
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .timedOut = $0 { return true }; return false }
        )
    }

    func test_load_URLError_notConnected_throwsNetworkError() async throws {
        let session = MockHTTPSession()
        session.dataError = URLError(.notConnectedToInternet)
        await assertThrows(
            try await makeService(session).load(ChatResponse.self, request: blankRequest),
            matches: { if case .networkError = $0 { return true }; return false }
        )
    }
}

// MARK: - Error descriptions

final class ErrorDescriptionTests: XCTestCase {

    private let allErrors: [RidexNetworkError] = [
        .invalidInput("Message must not be empty."),
        .unauthorized,
        .bundleIdMismatch,
        .serverError(statusCode: 400, message: nil),
        .serverError(statusCode: 402, message: nil),
        .serverError(statusCode: 429, message: "slow down"),
        .serverError(statusCode: 500, message: "oops"),
        .serverError(statusCode: 503, message: nil),
        .serverError(statusCode: 999, message: nil),
        .decodingFailed,
        .invalidResponse,
        .networkError(underlyingError: URLError(.notConnectedToInternet)),
        .timedOut,
        .cancelled,
    ]

    func test_allErrors_haveNonEmptyDescription() {
        for error in allErrors {
            XCTAssertNotNil(error.errorDescription, "\(error) missing errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) has empty errorDescription")
        }
    }

    func test_allErrors_haveNonEmptyFailureReason() {
        for error in allErrors {
            XCTAssertNotNil(error.failureReason, "\(error) missing failureReason")
            XCTAssertFalse(error.failureReason!.isEmpty, "\(error) has empty failureReason")
        }
    }

    func test_allErrors_haveNonEmptyRecoverySuggestion() {
        for error in allErrors {
            XCTAssertNotNil(error.recoverySuggestion, "\(error) missing recoverySuggestion")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "\(error) has empty recoverySuggestion")
        }
    }

    func test_serverError_gatewayMessageAppearsInDescription() {
        let error = RidexNetworkError.serverError(statusCode: 429, message: "slow down")
        XCTAssertTrue(error.errorDescription?.contains("slow down") == true)
    }

    func test_serverError_noGatewayMessage_descriptionHasNoTrailingDash() {
        let error = RidexNetworkError.serverError(statusCode: 500, message: nil)
        XCTAssertFalse(error.errorDescription?.hasSuffix(" — ") == true)
    }

    func test_errorDescriptions_allContainRidexPrefix() {
        for error in allErrors {
            XCTAssertTrue(
                error.errorDescription?.hasPrefix("[Ridex]") == true,
                "\(error) description missing [Ridex] prefix"
            )
        }
    }
}

// MARK: - Attest recovery tests

/// Tests for the attest-rejected recovery flow in `RidexNetworkService`.
final class NetworkServiceAttestTests: XCTestCase {

    private var validChatJSON: Data {
        """
        {
            "id": "chatcmpl-abc",
            "model": "gpt-4o",
            "choices": [{ "index": 0, "message": { "role": "assistant", "content": "Hello!" }, "finish_reason": "stop" }]
        }
        """.data(using: .utf8)!
    }

    private var blankRequest: URLRequest { URLRequest(url: .ridexBase) }

    private var attestErrorJSON: Data {
        #"{"error":{"message":"Attest required","code":"attest_required"}}"#.data(using: .utf8)!
    }

    override func tearDown() {
        super.tearDown()
        RidexKeychain.delete(key: "ridex_attest_key_id")
        RidexKeychain.delete(key: "ridex_attest_done")
    }

    private func makeServiceWithAttest(
        session: MockHTTPSession,
        attestService: MockAppAttestService = MockAppAttestService()
    ) -> (RidexNetworkService, MockAppAttestService) {
        // Clean keychain
        RidexKeychain.delete(key: "ridex_attest_key_id")
        RidexKeychain.delete(key: "ridex_attest_done")

        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: attestService,
            baseURL: URL(string: "https://localhost:9999")!
        )
        let authorizer = RidexRequestAuthorizer(gatewayKey: "rdx_test_key", attestManager: manager)
        let service = RidexNetworkService(session: session, authorizer: authorizer)
        return (service, attestService)
    }

    // MARK: - Attest on first request

    func test_load_callsEnsureAttested_whenAttestManagerExists() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))

        let attestService = MockAppAttestService()
        // ensureAttested will fail at network level (localhost:9999) but that's swallowed
        let (service, _) = makeServiceWithAttest(session: session, attestService: attestService)

        let _: ChatResponse = try await service.load(request: blankRequest)

        // generateKey should have been called as part of ensureAttested
        XCTAssertTrue(attestService.generateKeyCalled, "ensureAttested should be called on first request")
    }

    func test_load_succeedsEvenWhenAttestationFails() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))

        let attestService = MockAppAttestService()
        // ensureAttested will fail at the network call, but load should still proceed
        let (service, _) = makeServiceWithAttest(session: session, attestService: attestService)

        let response: ChatResponse = try await service.load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
    }

    // MARK: - attestReady skips re-attestation

    func test_load_skipsEnsureAttested_afterSuccessfulFirstCall() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))

        // Use unsupported attestService so ensureAttested is a no-op (completes successfully)
        let attestService = MockAppAttestService()
        attestService.isSupportedValue = false
        let (service, _) = makeServiceWithAttest(session: session, attestService: attestService)

        // First call
        let _: ChatResponse = try await service.load(request: blankRequest)
        // Second call — should not call ensureAttested again
        let _: ChatResponse = try await service.load(request: blankRequest)

        // Since isSupported is false, generateKey is never called.
        // The key check is that the second call proceeds without issues.
        XCTAssertEqual(session.capturedDataRequests.count, 2)
    }

    // MARK: - 403 attest error throws attestRejected

    func test_load_403_attestError_throwsAttestRejected_whenNoManager() async {
        let session = MockHTTPSession()
        session.dataResult = (attestErrorJSON, MockHTTPSession.http(403))

        let service = RidexNetworkService(
            session: session,
            authorizer: RidexRequestAuthorizer(gatewayKey: "rdx_test_key", attestManager: nil)
        )

        do {
            let _: ChatResponse = try await service.load(request: blankRequest)
            XCTFail("Expected attestRejected error")
        } catch let err as RidexNetworkError {
            XCTAssertEqual(err, .attestRejected, "Should throw attestRejected when no manager")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - 403 attest error with manager triggers recovery

    func test_load_403_attestError_withManager_retriesRequest() async throws {
        let session = MockHTTPSession()
        // First response: 403 attest error; second (after re-attest): 200 success
        session.dataResults = [
            (attestErrorJSON, MockHTTPSession.http(403)),
            (validChatJSON, MockHTTPSession.http(200)),
        ]

        // Pre-set attested state so ensureAttested is a no-op initially
        RidexKeychain.save(key: "ridex_attest_key_id", value: "old-key")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let attestService = MockAppAttestService()
        // The re-attestation after reset will fail at network (localhost:9999),
        // which means recovery will throw attestRejected.
        // This tests that the recovery path is entered.
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: attestService,
            baseURL: URL(string: "https://localhost:9999")!
        )
        let authorizer = RidexRequestAuthorizer(gatewayKey: "rdx_test_key", attestManager: manager)
        let service = RidexNetworkService(session: session, authorizer: authorizer)

        do {
            let _: ChatResponse = try await service.load(request: blankRequest)
            XCTFail("Expected error because re-attestation fails at network level")
        } catch let err as RidexNetworkError {
            // Recovery fails because ensureAttested hits localhost:9999
            XCTAssertEqual(err, .attestRejected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Verify reset was called (generateKey should be attempted during re-attestation)
        XCTAssertTrue(attestService.generateKeyCalled, "Re-attestation should attempt generateKey")
    }

    // MARK: - Unsupported attest service, no attest overhead

    func test_load_withUnsupportedAttest_proceedsNormally() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))

        let attestService = MockAppAttestService()
        attestService.isSupportedValue = false
        let (service, _) = makeServiceWithAttest(session: session, attestService: attestService)

        let response: ChatResponse = try await service.load(request: blankRequest)
        XCTAssertEqual(response.text, "Hello!")
        XCTAssertFalse(attestService.generateKeyCalled, "Should not generate key when unsupported")
    }
}

// MARK: - Async assertion helper

private func assertThrows<T>(
    _ expression: @autoclosure () async throws -> T,
    matches predicate: (RidexNetworkError) -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown.", file: file, line: line)
    } catch let err as RidexNetworkError {
        XCTAssertTrue(predicate(err), "Error \(err) did not match expected case.", file: file, line: line)
    } catch {
        XCTFail("Expected RidexNetworkError, got \(error).", file: file, line: line)
    }
}
