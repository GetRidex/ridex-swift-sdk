import XCTest
@testable import RidexSwiftSDK

// MARK: - RequestFactoryTests

/// Tests for `RidexRequestFactory`.
///
/// Verifies URL construction, HTTP method, and JSON body encoding.
final class RequestFactoryTests: XCTestCase {

    private var factory: RidexRequestFactory { RidexRequestFactory() }

    // MARK: - URL construction

    func test_make_chat_buildsCorrectURL() throws {
        let request = try factory.make(for: .chat)
        XCTAssertEqual(
            request.url?.absoluteString,
            "\(RidexGateway.baseURL)/\(RidexGateway.Route.chatCompletions)"
        )
    }

    // MARK: - HTTP method

    func test_make_chat_usesPostMethod() throws {
        let request = try factory.make(for: .chat)
        XCTAssertEqual(request.httpMethod, "POST")
    }

    // MARK: - Body encoding

    func test_make_noBody_nilHttpBody() throws {
        let request = try factory.make(for: .chat)
        XCTAssertNil(request.httpBody)
    }

    func test_make_withBody_encodesAsJSON() throws {
        struct Payload: Encodable { let name: String }
        let request = try factory.make(for: .chat, body: Payload(name: "test"))

        let data = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "test")
    }

    func test_make_withBody_encodesMessages() throws {
        let body    = ChatRequest(messages: [.user("Hello")])
        let request = try factory.make(for: .chat, body: body)

        let data = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let msgs = try XCTUnwrap(json["messages"] as? [[String: Any]])

        XCTAssertEqual(msgs.first?["role"]    as? String, "user")
        XCTAssertEqual(msgs.first?["content"] as? String, "Hello")
    }
}
