//
//  RidexConfig.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

extension RidexClient {

    /// The environment a ``RidexClient`` operates in.
    ///
    /// Inferred automatically from the key prefix:
    /// - `rdx_live_…` → `.production`
    /// - `rdx_test_…` → `.development`
    public enum Environment: String, Sendable {
        /// Production — use with `rdx_live_…` keys and App Store builds.
        case production  = "prod"
        /// Development — use with `rdx_test_…` keys and simulator / TestFlight builds.
        case development = "dev"

        static func inferred(from apiKey: String) -> Environment {
            apiKey.hasPrefix("rdx_live_") ? .production : .development
        }
    }
}
