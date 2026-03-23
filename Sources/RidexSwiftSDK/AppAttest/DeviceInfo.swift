//
//  DeviceInfo.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects non-PII device metadata for abuse detection.
/// All values come from public APIs that require no permissions.
enum DeviceInfo {

    /// Hardware model identifier, e.g. "iPhone15,2".
    static var model: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    /// OS version string, e.g. "17.4.1".
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// App's CFBundleShortVersionString, e.g. "2.1.0".
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// Locale identifier, e.g. "en_US".
    static var locale: String {
        Locale.current.identifier
    }

    /// All metadata as HTTP headers.
    static var headers: [String: String] {
        [
            "X-Ridex-Device-Model":  model,
            "X-Ridex-OS-Version":    osVersion,
            "X-Ridex-App-Version":   appVersion,
            "X-Ridex-Locale":        locale,
        ]
    }
}
