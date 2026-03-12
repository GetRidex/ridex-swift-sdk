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
