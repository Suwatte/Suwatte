//
//  WKR+Auth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

extension WKRunner: DSKAuthDelegate {
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        try await eval(script("let data = await RunnerObject.getAuthenticatedUser();"))
    }

    func handleUserSignOut() async throws {
        try await eval("await RunnerObject.handleUserSignOut()")
    }

    func handleBasicAuthentication(id: String, password: String) async throws {
        let args = ["id": id, "password": password]
        try await eval("await RunnerObject.handleBasicAuth(id, password)", args)
    }

    func getWebAuthRequestURL() async throws -> DSKCommon.BasicURL {
        try await eval(script("let data = await RunnerObject.getWebAuthRequestURL()"))
    }

    func didReceiveCookieFromWebAuthResponse(name: String) async throws -> DSKCommon.BooleanState {
        try await eval(script("let data = await RunnerObject.didReceiveSessionCookieFromWebAuthResponse(name)"),
                       ["name": name])
    }

    func getOAuthRequestURL() async throws -> DSKCommon.BasicURL {
        try await eval(script("let data = await RunnerObject.getOAuthRequestURL()"))
    }

    func handleOAuthCallback(response: String) async throws {
        try await eval("await RunnerObject.handleOAuthCallback(response)", ["response": response])
    }
}
