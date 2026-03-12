import XCTest
@testable import RidexSwiftSDK

// MARK: - RidexClientTests

/// Tests for `RidexClient` environment inference and the `prompt()` public method.
///
/// Network calls are made through an injected `MockHTTPSession`
/// via the internal test initialiser.
final class RidexClientTests: XCTestCase {

    // MARK: - Helpers

    private var validChatJSON: Data {
        """
        {
            "id": "chatcmpl-test",
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": { "role": "assistant", "content": "42." },
                "finish_reason": "stop"
            }]
        }
        """.data(using: .utf8)!
    }

    private func makeClient(
        apiKey:  String = "rdx_live_test",
        session: MockHTTPSession = MockHTTPSession()
    ) -> RidexClient {
        let service = RidexNetworkService(
            session: session,
            authorizer: RidexRequestAuthorizer(gatewayKey: apiKey)
        )
        return RidexClient(apiKey: apiKey, networkService: service)
    }

    // MARK: - Environment inference

    func test_env_liveKeyPrefix_infersProduction() {
        let client = makeClient(apiKey: "rdx_live_abc123")
        XCTAssertEqual(client.env, .production)
    }

    func test_env_testKeyPrefix_infersDevelopment() {
        let client = makeClient(apiKey: "rdx_test_abc123")
        XCTAssertEqual(client.env, .development)
    }

    // MARK: - Public init

    func test_publicInit_inferesProductionEnvFromLiveKey() {
        let client = RidexClient("rdx_live_abc123")
        XCTAssertEqual(client.env, .production)
    }

    func test_publicInit_inferesDevelopmentEnvFromTestKey() {
        let client = RidexClient("rdx_test_abc123")
        XCTAssertEqual(client.env, .development)
    }

    // MARK: - prompt()

    func test_prompt_onSuccess_returnsReplyText() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(session: session)

        let reply = try await client.prompt("What is the answer?")

        XCTAssertEqual(reply, "42.")
    }

    func test_prompt_sendsRequestToCorrectEndpoint() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(session: session)

        let _ = try await client.prompt("Hi")

        let request = try XCTUnwrap(session.capturedDataRequests.first)
        XCTAssertTrue(
            request.url?.path.hasSuffix("/v1/chat/completions") == true,
            "Expected /v1/chat/completions path, got \(request.url?.path ?? "nil")"
        )
    }

    func test_prompt_setsXRidexEnvHeader() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(apiKey: "rdx_live_abc", session: session)

        let _ = try await client.prompt("Hi")

        let request = try XCTUnwrap(session.capturedDataRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ridex-Env"), "prod")
    }

    func test_prompt_withFeatureTag_setsHeader() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(session: session)

        let _ = try await client.prompt("Hi", featureTag: "onboarding")

        let request = try XCTUnwrap(session.capturedDataRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ridex-Feature"), "onboarding")
    }

    func test_prompt_withUserTag_setsHeader() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(session: session)

        let _ = try await client.prompt("Hi", userTag: "user_789")

        let request = try XCTUnwrap(session.capturedDataRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ridex-User-ID"), "user_789")
    }

    func test_prompt_on401_throwsNetworkError() async throws {
        let session = MockHTTPSession()
        session.dataResult = (Data(), MockHTTPSession.http(401))
        let client = makeClient(session: session)

        do {
            let _ = try await client.prompt("Hi")
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            XCTAssertEqual(err, .unauthorized)
        }
    }

    func test_prompt_withContext_prependsSystemMessage() async throws {
        let session = MockHTTPSession()
        session.dataResult = (validChatJSON, MockHTTPSession.http(200))
        let client = makeClient(session: session)

        let _ = try await client.prompt("Hi", context: "You are a helpful assistant.")

        let request  = try XCTUnwrap(session.capturedDataRequests.first)
        let data     = try XCTUnwrap(request.httpBody)
        let json     = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"]    as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "You are a helpful assistant.")
        XCTAssertEqual(messages[1]["role"]    as? String, "user")
    }

    func test_prompt_emptyMessage_throwsInvalidInput() async throws {
        let client = makeClient()
        do {
            let _ = try await client.prompt("")
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            if case .invalidInput = err { /* pass */ }
            else { XCTFail("Expected .invalidInput, got \(err)") }
        }
    }

    func test_prompt_messageTooLong_throwsInvalidInput() async throws {
        let client = makeClient()
        let tooLong = String(repeating: "a", count: 32_001)
        do {
            let _ = try await client.prompt(tooLong)
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            if case .invalidInput = err { /* pass */ }
            else { XCTFail("Expected .invalidInput, got \(err)") }
        }
    }

    func test_prompt_contextTooLong_throwsInvalidInput() async throws {
        let client = makeClient()
        let tooLong = String(repeating: "a", count: 32_001)
        do {
            let _ = try await client.prompt("Hi", context: tooLong)
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            if case .invalidInput = err { /* pass */ }
            else { XCTFail("Expected .invalidInput, got \(err)") }
        }
    }

    func test_prompt_emptyMessage_invalidInput_containsReason() async throws {
        let client = makeClient()
        do {
            let _ = try await client.prompt("")
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            guard case .invalidInput(let reason) = err else {
                XCTFail("Expected .invalidInput, got \(err)"); return
            }
            XCTAssertFalse(reason.isEmpty)
        }
    }

    func test_prompt_onNetworkTimeout_throwsTimedOut() async throws {
        let session = MockHTTPSession()
        session.dataError = URLError(.timedOut)
        let client = makeClient(session: session)

        do {
            let _ = try await client.prompt("Hi")
            XCTFail("Expected error")
        } catch let err as RidexNetworkError {
            if case .timedOut = err { /* pass */ }
            else { XCTFail("Expected .timedOut, got \(err)") }
        }
    }

    // MARK: - Message convenience inits

    func test_message_systemConvenienceInit() {
        let msg = Message.system("Be helpful.")
        XCTAssertEqual(msg.role,    .system)
        XCTAssertEqual(msg.content, "Be helpful.")
    }

    func test_message_userConvenienceInit() {
        let msg = Message.user("What time is it?")
        XCTAssertEqual(msg.role,    .user)
        XCTAssertEqual(msg.content, "What time is it?")
    }

    func test_message_assistantConvenienceInit() {
        let msg = Message.assistant("It's noon.")
        XCTAssertEqual(msg.role,    .assistant)
        XCTAssertEqual(msg.content, "It's noon.")
    }
}
