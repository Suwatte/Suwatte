//
//  DSK+CS+Authentication.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation

extension DSKCommon {
    enum AuthMethod: Int, Codable {
        case username_pw, email_pw, web, oauth

        var isBasic: Bool {
            self == .username_pw || self == .email_pw
        }
    }

    struct User: Parsable, Hashable {
        var id: String
        var username: String
        var avatar: String?
        var info: [String]?
    }
}

// MARK: Get Auth Method

extension DSK.ContentSource {
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        try await withCheckedThrowingContinuation { handler in
            let method = "getAuthenticatedUser"
            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }

            runnerClass.daisukeCall(method: method, arguments: []) { value in
                if value.isNull {
                    handler.resume(returning: nil)
                    return
                }
                do {
                    let object = try DSKCommon.User(value: value)
                    handler.resume(returning: object)
                } catch {
                    handler.resume(throwing: error)
                }

            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}

extension DSK.ContentSource {
    func handleUserSignOut() async throws {
        try await callOptionalVoidMethod(method: "handleUserSignOut", arguments: [])
    }
}

extension DSK.ContentSource {
    func handleBasicAuth(id: String, password: String) async throws {
        if !methodExists(method: "handleBasicAuth") {
            throw DSK.Errors.NamedError(name: "Implementation Error", message: "Source Author has not implemented the required handleBasicAuth Method. Please reach out to the maintainer")
        }
        try await callOptionalVoidMethod(method: "handleBasicAuth", arguments: [id, password])
    }
}

// MARK: Web

extension DSK.ContentSource {
    func willRequestWebViewAuth() async throws -> DSKCommon.Request {
        let method = "willRequestWebViewAuth"
        if !methodExists(method: method) {
            throw DSK.Errors.NamedError(name: "Implementation Error", message: "Source Author Failed to Implement required functions to use WebView Authentication [\(method)]")
        }
        return try await callMethodReturningObject(method: method, arguments: [], resolvesTo: DSKCommon.Request.self)
    }

    func didReceiveWebAuthCookie(name: String) async throws -> Bool {
        let method = "didReceiveWebAuthCookie"
        if !methodExists(method: method) {
            throw DSK.Errors.NamedError(name: "Implementation Error", message: "Source Author Failed to Implement required functions to use WebView Authentication [\(method)]")
        }

        return try await callMethodReturningDecodable(method: method, arguments: [name], resolvesTo: Bool.self)
    }
}
