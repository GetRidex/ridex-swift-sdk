//
//  AttestManager.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import CryptoKit
import Security

actor AttestManager {

    private let gatewayKey: String
    private let attestService: AppAttestServiceProtocol
    private let baseURL: URL

    private var keyId: String?
    private var isAttested: Bool = false
    private var lastAttestAttempt: Date?
    private static let attestCooldown: TimeInterval = 30

    private static let keychainKeyId    = "ridex_attest_key_id"
    private static let keychainAttested = "ridex_attest_done"

    init(
        gatewayKey: String,
        attestService: AppAttestServiceProtocol = LiveAppAttestService(),
        baseURL: URL = RidexGateway.baseURL
    ) {
        self.gatewayKey = gatewayKey
        self.attestService = attestService
        self.baseURL = baseURL
        self.keyId = RidexKeychain.load(key: Self.keychainKeyId)
        self.isAttested = RidexKeychain.load(key: Self.keychainAttested) == "true"
    }

    var isSupported: Bool { attestService.isSupported }

    func ensureAttested() async throws {
        guard attestService.isSupported else { return }
        guard !isAttested else { return }

        if let last = lastAttestAttempt, Date().timeIntervalSince(last) < Self.attestCooldown {
            throw RidexNetworkError.attestRejected(
                detail: "Attestation cooldown active. Retry in \(Int(Self.attestCooldown - Date().timeIntervalSince(last)))s."
            )
        }
        lastAttestAttempt = Date()

        if keyId == nil {
            let newKeyId = try await attestService.generateKey()
            self.keyId = newKeyId
            RidexKeychain.save(key: Self.keychainKeyId, value: newKeyId)
        }

        guard let keyId else { return }

        let challenge = try await requestChallenge(deviceKeyId: keyId)

        guard let challengeData = Data(base64Encoded: challenge) else {
            throw RidexNetworkError.decodingFailed
        }
        let challengeHash = Data(SHA256.hash(data: challengeData))
        let attestation = try await attestService.attestKey(keyId, clientDataHash: challengeHash)

        try await registerAttestation(keyId: keyId, attestation: attestation)

        self.isAttested = true
        RidexKeychain.save(key: Self.keychainAttested, value: "true")
    }

    func assertionHeaders(for bodyData: Data) async throws -> [String: String] {
        guard attestService.isSupported, isAttested, let keyId else { return [:] }

        let clientDataHash = Data(SHA256.hash(data: bodyData))
        let assertion = try await attestService.generateAssertion(keyId, clientDataHash: clientDataHash)

        return [
            "X-Ridex-Attest-Key-ID":   keyId,
            "X-Ridex-Attest-Assertion": assertion.base64EncodedString(),
        ]
    }

    func reset() {
        keyId = nil
        isAttested = false
        lastAttestAttempt = nil
        RidexKeychain.delete(key: Self.keychainKeyId)
        RidexKeychain.delete(key: Self.keychainAttested)
    }

    private func requestChallenge(deviceKeyId: String? = nil) async throws -> String {
        let url = baseURL.appendingPathComponent("api/attest")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(gatewayKey)", forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = ["action": "challenge"]
        if let deviceKeyId { payload["deviceKeyId"] = deviceKeyId }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RidexNetworkError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get attestation challenge"
            )
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let challenge = json?["challenge"] as? String else {
            throw RidexNetworkError.decodingFailed
        }
        return challenge
    }

    private func registerAttestation(keyId: String, attestation: Data) async throws {
        let url = baseURL.appendingPathComponent("api/attest")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(gatewayKey)", forHTTPHeaderField: "Authorization")

        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Ridex-Bundle-ID")
        }
        if let teamId = Self.teamIdentifier {
            request.setValue(teamId, forHTTPHeaderField: "X-Ridex-Team-ID")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": "register",
            "keyId": keyId,
            "attestation": attestation.base64EncodedString(),
        ])

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let serverMessage = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])?["error"] as? String
            throw RidexNetworkError.serverError(
                statusCode: statusCode,
                message: serverMessage ?? "Attestation registration failed"
            )
        }
    }

    private static var teamIdentifier: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ridex_team_id_probe",
            kSecAttrService as String: "ridex_team_id_probe",
            kSecValueData as String: Data("probe".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnAttributes as String: true,
        ]

        SecItemDelete(query as CFDictionary)

        var result: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &result)

        defer { SecItemDelete(query as CFDictionary) }

        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let accessGroup = attrs[kSecAttrAccessGroup as String] as? String else {
            return nil
        }

        guard let dotIndex = accessGroup.firstIndex(of: ".") else { return nil }
        let teamId = String(accessGroup[accessGroup.startIndex..<dotIndex])
        return teamId.isEmpty ? nil : teamId
    }
}
