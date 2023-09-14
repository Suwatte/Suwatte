//
//  JSCR+Auth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

// MARK: - Authenticatable

extension JSCRunner: DSKAuthDelegate {
    // Auth
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        return try await callMethodReturningDecodable(method: "getAuthenticatedUser", arguments: [], resolvesTo: DSKCommon.User?.self)
    }

    func handleUserSignOut() async throws {
        try await callOptionalVoidMethod(method: "handleUserSignOut", arguments: [])
    }

    // Basic Auth
    func handleBasicAuthentication(id: String, password: String) async throws {
        try await callOptionalVoidMethod(method: "handleBasicAuth", arguments: [id, password])
    }

    // Web Auth
    func getWebAuthRequestURL() async throws -> DSKCommon.BasicURL {
        return try await callMethodReturningObject(method: "getWebAuthRequestURL", arguments: [], resolvesTo: DSKCommon.BasicURL.self)
    }

    func didReceiveCookieFromWebAuthResponse(name: String) async throws -> DSKCommon.BooleanState {
        return try await callMethodReturningDecodable(method: "didReceiveSessionCookieFromWebAuthResponse", arguments: [name], resolvesTo: DSKCommon.BooleanState.self)
    }

    // OAuth
    func getOAuthRequestURL() async throws -> DSKCommon.BasicURL {
        return try await callMethodReturningObject(method: "getOAuthRequestURL", arguments: [], resolvesTo: DSKCommon.BasicURL.self)
    }

    func handleOAuthCallback(response: String) async throws {
        try await callOptionalVoidMethod(method: "handleOAuthCallback", arguments: [response])
    }
}
