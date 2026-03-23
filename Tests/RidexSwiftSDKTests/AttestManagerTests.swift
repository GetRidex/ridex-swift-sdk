import XCTest
@testable import RidexSwiftSDK

// MARK: - AttestManagerTests

/// Tests for the `AttestManager` actor.
///
/// Uses `MockAppAttestService` to avoid real Apple DeviceCheck calls
/// and a `MockHTTPSession`-backed URL session to intercept network requests.
/// Note: Because `AttestManager` uses `URLSession.shared` directly for its
/// internal network calls (challenge + register), we cannot easily mock those.
/// Tests that involve `ensureAttested()` completing fully would require a real
/// server. Instead, we test the parts we can control:
///   - `isSupported` delegation
///   - `assertionHeaders` returning empty when not attested
///   - `assertionHeaders` calling generateAssertion when attested
///   - `reset` clearing state
///   - `ensureAttested` short-circuiting when not supported
///   - `ensureAttested` short-circuiting when already attested
final class AttestManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeManager(
        service: MockAppAttestService = MockAppAttestService(),
        gatewayKey: String = "rdx_test_attest_key"
    ) -> AttestManager {
        // Clean up keychain state to ensure test isolation
        RidexKeychain.delete(key: "ridex_attest_key_id")
        RidexKeychain.delete(key: "ridex_attest_done")

        return AttestManager(
            gatewayKey: gatewayKey,
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!  // unreachable on purpose
        )
    }

    override func tearDown() {
        super.tearDown()
        // Clean up keychain after each test
        RidexKeychain.delete(key: "ridex_attest_key_id")
        RidexKeychain.delete(key: "ridex_attest_done")
    }

    // MARK: - isSupported

    func test_isSupported_delegatesToService_true() async {
        let service = MockAppAttestService()
        service.isSupportedValue = true
        let manager = makeManager(service: service)
        let result = await manager.isSupported
        XCTAssertTrue(result)
    }

    func test_isSupported_delegatesToService_false() async {
        let service = MockAppAttestService()
        service.isSupportedValue = false
        let manager = makeManager(service: service)
        let result = await manager.isSupported
        XCTAssertFalse(result)
    }

    // MARK: - ensureAttested (short-circuit paths)

    func test_ensureAttested_noop_whenNotSupported() async throws {
        let service = MockAppAttestService()
        service.isSupportedValue = false
        let manager = makeManager(service: service)

        // Should not throw, and should not call generateKey
        try await manager.ensureAttested()
        XCTAssertFalse(service.generateKeyCalled, "Should not generate key when unsupported")
    }

    func test_ensureAttested_generatesKey_whenSupported() async {
        let service = MockAppAttestService()
        service.isSupportedValue = true
        let manager = makeManager(service: service)

        // ensureAttested will generate a key but then fail at requestChallenge
        // (because baseURL points to localhost:9999). That's expected.
        do {
            try await manager.ensureAttested()
        } catch {
            // Expected: network call to challenge endpoint will fail
        }

        XCTAssertTrue(service.generateKeyCalled, "Should have called generateKey")
    }

    func test_ensureAttested_doesNotSetAttested_onNetworkFailure() async {
        let service = MockAppAttestService()
        let manager = makeManager(service: service)

        // Will fail at the challenge network call
        do {
            try await manager.ensureAttested()
        } catch {
            // Expected
        }

        // assertionHeaders should return empty because attestation didn't complete
        let body = Data("test".utf8)
        let headers = try? await manager.assertionHeaders(for: body)
        XCTAssertEqual(headers ?? [:], [:], "Should not be attested after failed ensureAttested")
    }

    // MARK: - assertionHeaders (not attested)

    func test_assertionHeaders_returnsEmptyDict_whenNotAttested() async throws {
        let service = MockAppAttestService()
        let manager = makeManager(service: service)

        let body = Data("request-body".utf8)
        let headers = try await manager.assertionHeaders(for: body)
        XCTAssertTrue(headers.isEmpty, "Should return empty headers when not attested")
        XCTAssertFalse(service.generateAssertionCalled, "Should not generate assertion when not attested")
    }

    func test_assertionHeaders_returnsEmptyDict_whenNotSupported() async throws {
        let service = MockAppAttestService()
        service.isSupportedValue = false
        let manager = makeManager(service: service)

        let body = Data("request-body".utf8)
        let headers = try await manager.assertionHeaders(for: body)
        XCTAssertTrue(headers.isEmpty)
    }

    // MARK: - assertionHeaders (attested via keychain)

    func test_assertionHeaders_returnsHeaders_whenAttestedViaKeychain() async throws {
        // Simulate a previously attested state by writing to keychain
        RidexKeychain.save(key: "ridex_attest_key_id", value: "pre-existing-key")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let service = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!
        )

        let body = Data("request-body".utf8)
        let headers = try await manager.assertionHeaders(for: body)

        XCTAssertEqual(headers["X-Ridex-Attest-Key-ID"], "pre-existing-key")
        XCTAssertNotNil(headers["X-Ridex-Attest-Assertion"])
        // Verify the assertion is base64 encoded
        let assertionBase64 = headers["X-Ridex-Attest-Assertion"]!
        XCTAssertNotNil(Data(base64Encoded: assertionBase64), "Assertion should be valid base64")
        XCTAssertTrue(service.generateAssertionCalled)
    }

    func test_assertionHeaders_passesKeyIdToService() async throws {
        RidexKeychain.save(key: "ridex_attest_key_id", value: "test-key-123")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let service = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!
        )

        let body = Data("body-data".utf8)
        _ = try await manager.assertionHeaders(for: body)

        XCTAssertEqual(service.generateAssertionArgs?.keyId, "test-key-123")
        XCTAssertNotNil(service.generateAssertionArgs?.clientDataHash)
    }

    // MARK: - reset

    func test_reset_clearsState() async throws {
        // Set up attested state via keychain
        RidexKeychain.save(key: "ridex_attest_key_id", value: "key-to-clear")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let service = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!
        )

        // Verify it's attested before reset
        let body = Data("test".utf8)
        let headersBefore = try await manager.assertionHeaders(for: body)
        XCTAssertFalse(headersBefore.isEmpty, "Should have headers before reset")

        // Reset
        await manager.reset()

        // After reset, should return empty headers
        let headersAfter = try await manager.assertionHeaders(for: body)
        XCTAssertTrue(headersAfter.isEmpty, "Should have no headers after reset")

        // Keychain should be cleared
        XCTAssertNil(RidexKeychain.load(key: "ridex_attest_key_id"))
        XCTAssertNil(RidexKeychain.load(key: "ridex_attest_done"))
    }

    func test_reset_allowsReAttestation() async {
        RidexKeychain.save(key: "ridex_attest_key_id", value: "old-key")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let service = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!
        )

        await manager.reset()

        // Now ensureAttested should run the full flow again (will fail at network, but generates key)
        do {
            try await manager.ensureAttested()
        } catch {
            // Expected network failure
        }

        XCTAssertTrue(service.generateKeyCalled, "Should attempt key generation after reset")
    }

    // MARK: - ensureAttested idempotency (via keychain pre-set)

    func test_ensureAttested_noops_whenAlreadyAttestedViaKeychain() async throws {
        RidexKeychain.save(key: "ridex_attest_key_id", value: "existing-key")
        RidexKeychain.save(key: "ridex_attest_done", value: "true")

        let service = MockAppAttestService()
        let manager = AttestManager(
            gatewayKey: "rdx_test_key",
            attestService: service,
            baseURL: URL(string: "https://localhost:9999")!
        )

        // Should short-circuit because isAttested is already true
        try await manager.ensureAttested()
        XCTAssertFalse(service.generateKeyCalled, "Should not generate key when already attested")
    }

    // MARK: - Key generation failure

    func test_ensureAttested_propagatesKeyGenerationError() async {
        let service = MockAppAttestService()
        service.generateKeyResult = .failure(NSError(domain: "test", code: 42))
        let manager = makeManager(service: service)

        do {
            try await manager.ensureAttested()
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }

        // Should not be attested
        let body = Data("test".utf8)
        let headers = try? await manager.assertionHeaders(for: body)
        XCTAssertEqual(headers ?? [:], [:])
    }
}
