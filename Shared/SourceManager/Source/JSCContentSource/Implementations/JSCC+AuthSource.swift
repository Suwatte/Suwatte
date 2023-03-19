//
//  JSCC+AuthSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation


extension JSCC : AuthSource {
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        let method = "getAuthenticatedUser"
        guard methodExists(method: method) else {
            throw DSK.Errors.MethodNotImplemented
        }
        return try await callMethodReturningDecodable(method: method, arguments: [], resolvesTo: DSKCommon.User.self)
    }
    
    func handleBasicAuthentication(id: String, password: String) async throws {
        if !methodExists(method: "handleBasicAuth") {
            throw DSK.Errors.MethodNotImplemented
        }
        try await callOptionalVoidMethod(method: "handleBasicAuth", arguments: [id, password])
    }
    
    func handleUserSignOut() async throws {
        try await callOptionalVoidMethod(method: "handleUserSignOut", arguments: [])
    }
    
    func willRequestAuthenticationWebView() async throws -> DSKCommon.Request {
        let method = "willRequestAuthenticationWebView"
        if !methodExists(method: method) {
            throw DSK.Errors.MethodNotImplemented
        }
        return try await callMethodReturningObject(method: method, arguments: [], resolvesTo: DSKCommon.Request.self)
    }
    
    func didReceiveAuthenticationCookieFromWebView(cookie: DSKCommon.Cookie) async throws -> Bool {
        let method = "didReceiveAuthenticationCookieFromWebView"
        if !methodExists(method: method) {
            throw DSK.Errors.MethodNotImplemented
        }
        let cookie = try cookie.asDictionary()
        return try await callMethodReturningDecodable(method: method, arguments: [cookie], resolvesTo: Bool.self)
    }
}
