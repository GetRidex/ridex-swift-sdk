import Foundation
@testable import RidexSwiftSDK

/// Test double for `AppAttestServiceProtocol`.
///
/// All method calls are recorded and results are configurable via `Result` properties.
final class MockAppAttestService: AppAttestServiceProtocol, @unchecked Sendable {

    // MARK: - isSupported

    var isSupportedValue = true
    var isSupported: Bool { isSupportedValue }

    // MARK: - generateKey

    var generateKeyResult: Result<String, Error> = .success("mock-key-id")
    private(set) var generateKeyCalled = false
    private(set) var generateKeyCallCount = 0

    func generateKey() async throws -> String {
        generateKeyCalled = true
        generateKeyCallCount += 1
        return try generateKeyResult.get()
    }

    // MARK: - attestKey

    var attestKeyResult: Result<Data, Error> = .success(Data("mock-attestation".utf8))
    private(set) var attestKeyCalled = false
    private(set) var attestKeyCallCount = 0
    private(set) var attestKeyArgs: (keyId: String, clientDataHash: Data)?

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        attestKeyCalled = true
        attestKeyCallCount += 1
        attestKeyArgs = (keyId, clientDataHash)
        return try attestKeyResult.get()
    }

    // MARK: - generateAssertion

    var generateAssertionResult: Result<Data, Error> = .success(Data("mock-assertion".utf8))
    private(set) var generateAssertionCalled = false
    private(set) var generateAssertionCallCount = 0
    private(set) var generateAssertionArgs: (keyId: String, clientDataHash: Data)?

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        generateAssertionCalled = true
        generateAssertionCallCount += 1
        generateAssertionArgs = (keyId, clientDataHash)
        return try generateAssertionResult.get()
    }
}
