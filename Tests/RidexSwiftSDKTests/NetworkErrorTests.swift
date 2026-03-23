import XCTest
@testable import RidexSwiftSDK

// MARK: - NetworkErrorTests

/// Tests for `RidexNetworkError` attest-related cases: descriptions, equality, and recovery guidance.
final class NetworkErrorTests: XCTestCase {

    // MARK: - attestNotSupported

    func test_attestNotSupported_hasErrorDescription() {
        let error = RidexNetworkError.attestNotSupported
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_attestNotSupported_hasRidexPrefix() {
        let error = RidexNetworkError.attestNotSupported
        XCTAssertTrue(error.errorDescription!.hasPrefix("[Ridex]"))
    }

    func test_attestNotSupported_hasFailureReason() {
        let error = RidexNetworkError.attestNotSupported
        XCTAssertNotNil(error.failureReason)
        XCTAssertFalse(error.failureReason!.isEmpty)
    }

    func test_attestNotSupported_hasRecoverySuggestion() {
        let error = RidexNetworkError.attestNotSupported
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    func test_attestNotSupported_recoverySuggestionMentionsSimulator() {
        let error = RidexNetworkError.attestNotSupported
        XCTAssertTrue(
            error.recoverySuggestion!.contains("Simulator") || error.recoverySuggestion!.contains("simulator"),
            "Recovery suggestion should mention simulators"
        )
    }

    // MARK: - attestRejected

    func test_attestRejected_hasErrorDescription() {
        let error = RidexNetworkError.attestRejected
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_attestRejected_hasRidexPrefix() {
        let error = RidexNetworkError.attestRejected
        XCTAssertTrue(error.errorDescription!.hasPrefix("[Ridex]"))
    }

    func test_attestRejected_hasFailureReason() {
        let error = RidexNetworkError.attestRejected
        XCTAssertNotNil(error.failureReason)
        XCTAssertFalse(error.failureReason!.isEmpty)
    }

    func test_attestRejected_hasRecoverySuggestion() {
        let error = RidexNetworkError.attestRejected
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    func test_attestRejected_recoverySuggestionMentionsReAttest() {
        let error = RidexNetworkError.attestRejected
        XCTAssertTrue(
            error.recoverySuggestion!.contains("re-attest"),
            "Recovery suggestion should mention re-attestation"
        )
    }

    // MARK: - Equatable

    func test_attestNotSupported_equalsItself() {
        XCTAssertEqual(RidexNetworkError.attestNotSupported, RidexNetworkError.attestNotSupported)
    }

    func test_attestRejected_equalsItself() {
        XCTAssertEqual(RidexNetworkError.attestRejected, RidexNetworkError.attestRejected)
    }

    func test_attestNotSupported_doesNotEqualAttestRejected() {
        XCTAssertNotEqual(RidexNetworkError.attestNotSupported, RidexNetworkError.attestRejected)
    }

    func test_attestNotSupported_doesNotEqualUnauthorized() {
        XCTAssertNotEqual(RidexNetworkError.attestNotSupported, RidexNetworkError.unauthorized)
    }

    func test_attestRejected_doesNotEqualUnauthorized() {
        XCTAssertNotEqual(RidexNetworkError.attestRejected, RidexNetworkError.unauthorized)
    }
}
