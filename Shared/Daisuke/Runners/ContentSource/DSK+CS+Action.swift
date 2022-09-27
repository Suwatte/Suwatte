//
//  DSK+CS+Action.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-26.
//

import Foundation


extension DSK.ContentSource {
    
    func getSourceActions() async throws -> [DSKCommon.ActionGroup]? {
        let method = "getSourceActions"
        if !methodExists(method: method) {
            return nil
        }
        return try await callMethodReturningDecodable(method: method, arguments: [], resolvesTo: [DSKCommon.ActionGroup].self)
    }
    
    func didTriggerAction(key: String) async throws {
        try await callOptionalVoidMethod(method: "didTriggerAction", arguments: [key])
    }
}
