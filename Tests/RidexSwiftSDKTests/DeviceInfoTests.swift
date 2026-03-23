import XCTest
@testable import RidexSwiftSDK

// MARK: - DeviceInfoTests

/// Tests for `DeviceInfo` static properties that collect non-PII device metadata.
final class DeviceInfoTests: XCTestCase {

    // MARK: - model

    func test_model_returnsNonEmptyString() {
        let model = DeviceInfo.model
        XCTAssertFalse(model.isEmpty, "DeviceInfo.model should not be empty")
    }

    // MARK: - osVersion

    func test_osVersion_matchesMajorMinorPatch() {
        let version = DeviceInfo.osVersion
        let pattern = #"^\d+\.\d+\.\d+$"#
        XCTAssertNotNil(
            version.range(of: pattern, options: .regularExpression),
            "osVersion '\(version)' should match major.minor.patch format"
        )
    }

    // MARK: - appVersion

    func test_appVersion_returnsString() {
        // In a test runner the bundle may not have CFBundleShortVersionString,
        // so the fallback "unknown" is acceptable.
        let version = DeviceInfo.appVersion
        XCTAssertFalse(version.isEmpty, "DeviceInfo.appVersion should not be empty")
    }

    // MARK: - locale

    func test_locale_returnsValidIdentifier() {
        let locale = DeviceInfo.locale
        XCTAssertFalse(locale.isEmpty, "DeviceInfo.locale should not be empty")
        // Locale identifiers contain letters, underscores, or hyphens.
        let pattern = #"^[a-zA-Z0-9_\-@.]+$"#
        XCTAssertNotNil(
            locale.range(of: pattern, options: .regularExpression),
            "locale '\(locale)' should be a valid identifier"
        )
    }

    // MARK: - headers

    func test_headers_containsAllExpectedKeys() {
        let headers = DeviceInfo.headers
        let expectedKeys: Set<String> = [
            "X-Ridex-Device-Model",
            "X-Ridex-OS-Version",
            "X-Ridex-App-Version",
            "X-Ridex-Locale",
        ]
        for key in expectedKeys {
            XCTAssertNotNil(headers[key], "headers should contain \(key)")
        }
    }

    func test_headers_valuesAreNonEmpty() {
        let headers = DeviceInfo.headers
        for (key, value) in headers {
            XCTAssertFalse(value.isEmpty, "Header \(key) should have a non-empty value")
        }
    }

    func test_headers_countMatchesExpected() {
        XCTAssertEqual(DeviceInfo.headers.count, 4, "headers should contain exactly 4 entries")
    }
}
