//
//  NetworkServiceError.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

public enum RidexNetworkError: Error {
    /// Input validation failed. See the associated `reason` for details.
    case invalidInput(_ reason: String)
    /// The gateway key is invalid or expired.
    case unauthorized
    /// The app is not authorised for this key.
    case bundleIdMismatch
    /// The gateway returned an error response.
    case serverError(statusCode: Int, message: String?)
    /// The gateway response could not be parsed.
    case decodingFailed
    /// An unexpected response was received.
    case invalidResponse
    /// A network error occurred.
    case networkError(underlyingError: Error)
    /// The request timed out.
    case timedOut
    /// The request was cancelled.
    case cancelled
    /// App Attest is required but not supported on this device.
    case attestNotSupported
    /// The server rejected the App Attest assertion (expired key, revoked device, or needs re-attestation).
    case attestRejected(detail: String? = nil)
}

extension RidexNetworkError: Equatable {
    public static func == (lhs: RidexNetworkError, rhs: RidexNetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidInput(let a), .invalidInput(let b)):
            return a == b
        case (.unauthorized, .unauthorized),
             (.bundleIdMismatch, .bundleIdMismatch),
             (.decodingFailed, .decodingFailed),
             (.invalidResponse, .invalidResponse),
             (.timedOut, .timedOut),
             (.cancelled, .cancelled):
            return true
        case (.serverError(let a, _), .serverError(let b, _)):
            return a == b
        case (.attestNotSupported, .attestNotSupported):
            return true
        case (.attestRejected, .attestRejected):
            return true
        default:
            return false
        }
    }
}

extension RidexNetworkError: LocalizedError {

    /// A short, human-readable description of what went wrong.
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return "[Ridex] Invalid input — \(reason)"

        case .unauthorized:
            return "[Ridex] Authentication failed."

        case .bundleIdMismatch:
            return "[Ridex] App not authorised for this key."

        case .serverError(let code, let message):
            return "[Ridex] \(Self.title(for: code))" + (message.map { " — \($0)" } ?? "")

        case .decodingFailed:
            return "[Ridex] Could not parse the gateway response."

        case .invalidResponse:
            return "[Ridex] Received an unexpected response from the server."

        case .networkError(let error):
            return "[Ridex] Network error — \(error.localizedDescription)"

        case .timedOut:
            return "[Ridex] Request timed out."

        case .cancelled:
            return "[Ridex] Request cancelled."

        case .attestNotSupported:
            return "[Ridex] App Attest is required but not supported on this device."

        case .attestRejected(let detail):
            if let detail {
                return "[Ridex] App Attest verification failed: \(detail)"
            }
            return "[Ridex] App Attest verification failed."
        }
    }

    /// A technical explanation of why the error occurred.
    public var failureReason: String? {
        switch self {
        case .invalidInput(let reason):
            return reason

        case .unauthorized:
            return "The gateway key is invalid or expired."

        case .bundleIdMismatch:
            return "The app is not authorised for this key."

        case .serverError(let code, _):
            return Self.reason(for: code)

        case .decodingFailed:
            return "The gateway response could not be parsed."

        case .invalidResponse:
            return "An unexpected response was received."

        case .networkError(let error):
            return error.localizedDescription

        case .timedOut:
            return "The request timed out."

        case .cancelled:
            return "The request was cancelled."

        case .attestNotSupported:
            return "This key requires App Attest but the device does not support it."

        case .attestRejected(let detail):
            if let detail {
                return "The device's attestation was rejected by the server: \(detail)"
            }
            return "The device's attestation was rejected by the server."
        }
    }

    /// Actionable guidance for resolving the error.
    public var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Check the argument highlighted in the error description and correct it before retrying."

        case .unauthorized:
            return "Verify your key in the Ridex dashboard under API Keys. " +
                   "Keys follow the format rdx_live_… (production) or rdx_test_… (development). " +
                   "Make sure you are calling Ridex.configure(_:) before sending any requests."

        case .bundleIdMismatch:
            return "Check the key's configuration in the Ridex dashboard under API Keys."

        case .serverError(let code, _):
            return Self.recovery(for: code)

        case .decodingFailed:
            return "Update the SDK to the latest version. If the issue persists, file a report at https://github.com/ridex/ridex-swift-sdk/issues."

        case .invalidResponse:
            return "Retry the request. If the issue persists, check https://getridex.com/status for gateway incidents."

        case .networkError:
            return "Check the device's internet connection and retry."

        case .timedOut:
            return "Retry the request. Contact support if timeouts are frequent."

        case .cancelled:
            return "No action required — this is expected when a user navigates away or a Task is explicitly cancelled."

        case .attestNotSupported:
            return "App Attest requires a real Apple device with iOS 14+. Simulators and older devices are not supported. " +
                   "Use a Development key (rdx_test_) for simulator testing."

        case .attestRejected:
            return "The SDK will automatically re-attest on the next request. If this persists, check the server error detail or verify the device has not been revoked in the Ridex dashboard."
        }
    }

    private static func title(for code: Int) -> String {
        switch code {
        case 400: return "Bad request."
        case 402: return "Budget cap reached."
        case 403: return "Forbidden."
        case 404: return "Not found."
        case 422: return "Unprocessable request."
        case 429: return "Rate limit exceeded."
        case 500: return "Gateway internal error."
        case 502: return "Bad gateway."
        case 503: return "Gateway unavailable."
        case 504: return "Gateway timeout."
        default:  return "An unexpected error occurred."
        }
    }

    private static func reason(for code: Int) -> String {
        switch code {
        case 400: return "The request body was malformed or contained invalid parameters."
        case 402: return "This project has hit its configured spending limit for the current period."
        case 403: return "The key does not have permission to perform this action."
        case 404: return "The requested API endpoint does not exist. The SDK may be out of date."
        case 422: return "The request was well-formed but contained semantic errors the gateway could not process."
        case 429: return "Too many requests. Please slow down."
        case 500: return "The gateway encountered an unexpected error."
        case 502: return "The gateway received an invalid response."
        case 503: return "The gateway is temporarily unavailable."
        case 504: return "The gateway did not respond in time."
        default:  return "An unexpected error occurred."
        }
    }

    private static func recovery(for code: Int) -> String {
        switch code {
        case 400: return "Check that you are passing a non-empty message. If the issue persists, contact support."
        case 402: return "Increase your budget cap in the Ridex dashboard → Settings → Budget, or wait for the next billing period."
        case 403: return "Check the key's permissions in the Ridex dashboard under API Keys."
        case 404: return "Update the SDK to the latest version."
        case 422: return "Review the request parameters and retry."
        case 429: return "Reduce request frequency and retry."
        case 500: return "Retry in a few seconds. Check https://getridex.com/status for ongoing incidents."
        case 502, 503: return "Retry in a moment. Check https://getridex.com/status for status updates."
        case 504: return "Retry the request. If the issue persists, contact support."
        default:  return "Retry the request. If the error persists, contact support."
        }
    }
}
