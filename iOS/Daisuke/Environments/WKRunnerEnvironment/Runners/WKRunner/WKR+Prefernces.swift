//
//  WKR+Prefernces.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

extension WKRunner: DSKPreferenceDelegate {
    func updatePreference(key: String, value: Any) async {
        do {
            let arguments: [String: Any] = ["key": key, "value": value]
            try await eval("await updateSourcePreferences(key, value)", arguments)
            Logger.shared.log("[\(key)] Preference Updated", id)
        } catch {
            Logger.shared.error("[\(key)] Preference Failed To Update: \(error)")
        }
    }

    func getPreferenceMenu() async throws -> DSKCommon.Form {
        try await eval(script("let data = await RunnerObject.getPreferenceMenu();"))
    }
}

extension WKRunner: DSKSetupDelegate {
    func getSetupMenu() async throws -> DSKCommon.Form {
        try await eval(script("let data = await RunnerObject.getSetupMenu();"))
    }

    func validateSetupForm(form: DSKCommon.CodableDict) async throws {
        try await eval("await RunnerObject.validateSetupForm(form);", ["form": form.asDictionary()])
    }
    
    func isRunnerSetup() async throws -> DSKCommon.BooleanState {
        try await eval(script("let data = await RunnerObject.isRunnerSetup();"))

    }
}
