//
//  DSK+CS+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation

typealias DSK = DaisukeEngine
typealias DSKCommon = DSK.Structs
extension DSK.ContentSource {
    func getUserPreferences() async throws -> [DSKCommon.PreferenceGroup]? {
        let methodName = "getUserPreferences"
        if !methodExists(method: methodName) {
            return nil
        }
        return try await callMethodReturningDecodable(method: methodName, arguments: [], resolvesTo: [DSKCommon.PreferenceGroup].self)
    }

    func didSetPreference(key: String, value: String) async throws {
        try await callOptionalVoidMethod(method: "getUserPreferences", arguments: [key, value])
    }
}
