//
//  WKR+Prefernces.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

extension WKRunner: DSKPreferenceDelegate {
    func updateSourcePreference(key: String, value: Any) async {
        do {
            let arguments: [String: Any] = ["key": key, "value": value]
            try await eval("await updateSourcePreferences(key, value)", arguments)
            Logger.shared.log("[\(key)] Preference Updated", runnerID)
        } catch {
            Logger.shared.error("[\(key)] Preference Failed To Update: \(error)")
        }
    }

    func buildPreferenceMenu() async throws -> [DSKCommon.PreferenceGroup] {
        try await eval(script("let data = await generatePreferenceMenu();"))
    }
}
