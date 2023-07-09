//
//  JSCCT+Implementation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation

typealias JSCCT = JSCContentTracker
extension JSCContentTracker {
    /// Returns the form to present to the user to update the entry form.
    func getEntryForm(id: String) async throws -> DSKCommon.TrackForm {
        try await callMethodReturningDecodable(method: "getEntryForm", arguments: [id], resolvesTo: DSKCommon.TrackForm .self)
    }
    
    /// Called when the user submits the entry form
    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws {
        let object = try form.asDictionary()
        try await callOptionalVoidMethod(method: "didSubmitEntryForm", arguments: [id, object])
    }
}
