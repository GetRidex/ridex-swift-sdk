//
//  RidexActor.swift
//  RidexSwiftSDK
//
//  Copyright © 2026 GetRidex. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//

/// A dedicated global actor that serialises access to Ridex shared state.
///
/// Isolating configuration behind its own actor keeps the main actor free
/// for UI work and lets `Ridex.prompt(_:)` be called from any context.
@globalActor
public actor RidexActor {
    public static let shared = RidexActor()
}
