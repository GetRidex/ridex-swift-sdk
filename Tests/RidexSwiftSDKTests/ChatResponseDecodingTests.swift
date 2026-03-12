import XCTest
@testable import RidexSwiftSDK

// MARK: - ChatResponseDecodingTests

/// Tests for `ChatResponse` JSON decoding.
final class ChatResponseDecodingTests: XCTestCase {

    // MARK: - Fixtures

    private let fullJSON = """
    {
        "id": "chatcmpl-xyz",
        "model": "gpt-4o",
        "choices": [
            {
                "index": 0,
                "message": { "role": "assistant", "content": "Paris." },
                "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 12,
            "completion_tokens": 4,
            "total_tokens": 16
        }
    }
    """

    private let multiChoiceJSON = """
    {
        "id": "chatcmpl-multi",
        "model": "gpt-4o",
        "choices": [
            { "index": 0, "message": { "role": "assistant", "content": "First."  }, "finish_reason": "stop" },
            { "index": 1, "message": { "role": "assistant", "content": "Second." }, "finish_reason": "stop" }
        ]
    }
    """

    private let emptyChoicesJSON = """
    { "id": "chatcmpl-empty", "model": "gpt-4o", "choices": [] }
    """

    private func decode(_ json: String) throws -> ChatResponse {
        try JSONDecoder().decode(ChatResponse.self, from: json.data(using: .utf8)!)
    }

    // MARK: - text

    func test_text_returnsFirstChoiceContent() throws {
        XCTAssertEqual(try decode(fullJSON).text, "Paris.")
    }

    func test_text_withMultipleChoices_returnsFirst() throws {
        XCTAssertEqual(try decode(multiChoiceJSON).text, "First.")
    }

    func test_text_withEmptyChoices_isEmpty() throws {
        XCTAssertEqual(try decode(emptyChoicesJSON).text, "")
    }

    // MARK: - Extra gateway fields

    func test_decode_extraFields_areIgnored() throws {
        // Gateway may return usage, model, system_fingerprint, etc. — all ignored.
        XCTAssertNoThrow(try decode(fullJSON))
    }

    // MARK: - Required fields

    func test_decode_missingChoices_throwsDecodingError() {
        XCTAssertThrowsError(try decode(#"{"id":"abc","model":"gpt-4o"}"#))
    }
}
