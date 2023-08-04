//
//  JSCR+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

// MARK: - Preferences
extension JSCRunner : DSKPreferenceDelegate {
    // Preference
    func buildPreferenceMenu() async throws -> [DSKCommon.PreferenceGroup] {
        return try await callContextMethod(method: "generatePreferenceMenu", resolvesTo: [DSKCommon.PreferenceGroup].self)
    }

    func updateSourcePreference(key: String, value: Any) async {
        let context = runnerClass.context!
        let function = context.evaluateScript("updateSourcePreferences")
        function?.daisukeCall(arguments: [key, value], onSuccess: { _ in
            context.evaluateScript("console.log('[\(key)] Preference Updated')")
        }, onFailure: { error in
            context.evaluateScript("console.error('[\(key)] Preference Failed To Update: \(error)')")

        })
    }
}

