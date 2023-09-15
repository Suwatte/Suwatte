//
//  JSCR+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

// MARK: - Preferences

extension JSCRunner: DSKPreferenceDelegate {
    // Preference
    func getPreferenceMenu() async throws -> DSKCommon.Form {
        try await callMethodReturningDecodable(method: "getPreferenceMenu",
                                               arguments: [],
                                               resolvesTo: DSKCommon.Form.self)
    }

    func updatePreference(key: String, value: Any) async {
        let context = runnerClass.context!
        let function = context.evaluateScript("updateSourcePreferences")
        function?.daisukeCall(arguments: [key, value], onSuccess: { _ in
            context.evaluateScript("console.log('[\(key)] Preference Updated')")
        }, onFailure: { error in
            context.evaluateScript("console.error('[\(key)] Preference Failed To Update: \(error)')")

        })
    }
}

extension JSCRunner: DSKSetupDelegate {
    func getSetupMenu() async throws -> DSKCommon.Form {
        try await callMethodReturningDecodable(method: "getSetupMenu",
                                               arguments: [],
                                               resolvesTo: DSKCommon.Form.self)
    }

    func validateSetupForm(form: DSKCommon.CodableDict) async throws {
        let object = try form.asDictionary()
        return try await callOptionalVoidMethod(method: "validateSetupForm", arguments: [object])
    }

    func isRunnerSetup() async throws -> DSKCommon.BooleanState {
        try await callMethodReturningDecodable(method: "isRunnerSetup",
                                               arguments: [],
                                               resolvesTo: DSKCommon.BooleanState.self)
    }
}
