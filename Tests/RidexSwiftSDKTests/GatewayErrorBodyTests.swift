import XCTest
@testable import RidexSwiftSDK

// MARK: - GatewayErrorBodyTests

/// Tests for `GatewayErrorBody` decoding and computed properties.
final class GatewayErrorBodyTests: XCTestCase {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> GatewayErrorBody {
        try JSONDecoder().decode(GatewayErrorBody.self, from: json.data(using: .utf8)!)
    }

    // MARK: - OAI format decoding

    func test_decode_oaiFormat_extractsMessageAndCode() throws {
        let json = #"{"error":{"message":"Rate limit exceeded","code":"rate_limit"}}"#
        let body = try decode(json)
        XCTAssertEqual(body.message, "Rate limit exceeded")
        XCTAssertEqual(body.code, "rate_limit")
    }

    func test_decode_oaiFormat_isBundleIdMismatch_isFalse() throws {
        let json = #"{"error":{"message":"Something","code":"rate_limit"}}"#
        let body = try decode(json)
        XCTAssertFalse(body.isBundleIdMismatch)
    }

    func test_decode_oaiFormat_withNullFields() throws {
        let json = #"{"error":{"message":null,"code":null}}"#
        let body = try decode(json)
        XCTAssertNil(body.message)
        XCTAssertNil(body.code)
    }

    // MARK: - Simple format decoding

    func test_decode_simpleFormat_extractsCodeAndMessage() throws {
        let json = #"{"error":"internal_error","message":"Something went wrong."}"#
        let body = try decode(json)
        XCTAssertEqual(body.code, "internal_error")
        XCTAssertEqual(body.message, "Something went wrong.")
    }

    func test_decode_simpleFormat_bundleIdMismatch() throws {
        let json = #"{"error":"bundle_id_mismatch","message":"Not authorized."}"#
        let body = try decode(json)
        XCTAssertTrue(body.isBundleIdMismatch)
        XCTAssertEqual(body.code, "bundle_id_mismatch")
    }

    // MARK: - isAttestError

    func test_isAttestError_attestRequired_returnsTrue() throws {
        let json = #"{"error":{"message":"Attest required","code":"attest_required"}}"#
        let body = try decode(json)
        XCTAssertTrue(body.isAttestError)
    }

    func test_isAttestError_deviceUnknown_returnsTrue() throws {
        let json = #"{"error":{"message":"Unknown device","code":"device_unknown"}}"#
        let body = try decode(json)
        XCTAssertTrue(body.isAttestError)
    }

    func test_isAttestError_invalidAssertion_returnsTrue() throws {
        let json = #"{"error":{"message":"Invalid assertion","code":"invalid_assertion"}}"#
        let body = try decode(json)
        XCTAssertTrue(body.isAttestError)
    }

    func test_isAttestError_rateLimit_returnsFalse() throws {
        let json = #"{"error":{"message":"Slow down","code":"rate_limit"}}"#
        let body = try decode(json)
        XCTAssertFalse(body.isAttestError)
    }

    func test_isAttestError_nilCode_returnsFalse() throws {
        let json = #"{"error":{"message":"Something"}}"#
        let body = try decode(json)
        XCTAssertFalse(body.isAttestError)
    }

    func test_isAttestError_simpleFormat_attestRequired_returnsTrue() throws {
        let json = #"{"error":"attest_required","message":"Please attest."}"#
        let body = try decode(json)
        XCTAssertTrue(body.isAttestError)
    }

    // MARK: - isBundleIdMismatch

    func test_isBundleIdMismatch_simpleFormat_returnsTrue() throws {
        let json = #"{"error":"bundle_id_mismatch","message":"Mismatch."}"#
        let body = try decode(json)
        XCTAssertTrue(body.isBundleIdMismatch)
    }

    func test_isBundleIdMismatch_differentCode_returnsFalse() throws {
        let json = #"{"error":"internal_error","message":"Something."}"#
        let body = try decode(json)
        XCTAssertFalse(body.isBundleIdMismatch)
    }

    func test_isBundleIdMismatch_oaiFormat_alwaysFalse() throws {
        // OAI format always sets isBundleIdMismatch to false
        let json = #"{"error":{"message":"Mismatch","code":"bundle_id_mismatch"}}"#
        let body = try decode(json)
        XCTAssertFalse(body.isBundleIdMismatch)
    }
}
