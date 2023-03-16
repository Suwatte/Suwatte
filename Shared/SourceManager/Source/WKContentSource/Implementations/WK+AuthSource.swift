//
//  WK+AuthSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-13.
//

import Foundation


extension WKContentSource : AuthSource {
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        let body = "return getAuthenticatedUser();"
        return try await eval(body, to: DSKCommon.User?.self)
    }
    
    func handleBasicAuthentication(id: String, password: String) async throws {
        let body = "return handleBasicAuthentication(id, password);"
        let arguments = ["id": id, "password": password]
        try await eval(body, arguments)
    }
    
    func handleUserSignOut() async throws {
        let body = "return handleUserSignOut();"
        try await eval(body)
    }
    
    func willRequestAuthenticationWebView() async throws -> DSKCommon.Request {
        let body = "return willRequestAuthenticationWebView();"
        return try await eval(body, to: DSKCommon.Request.self)
    }
    
    func didReceiveAuthenticationCookieFromWebView(cookie: DSKCommon.Cookie) async throws -> Bool {
        let body = "return didReceiveAuthenticationCookieFromWebView(cookie);"
        let arguments = ["cookie": try cookie.asDictionary()]
        let value = try await eval(body, arguments, to: [String: Bool].self)
        let out = value["didReceive"] ?? false
        return out
    }
}
