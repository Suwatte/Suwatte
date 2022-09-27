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

    struct SyncedContent: Parsable, Hashable {
        var id: String
        var title: String
        var covers: [String]
        var readingFlag: LibraryFlag
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

    func getUserLibrary() async throws -> [DSKCommon.SyncedContent] {
        try await callMethodReturningDecodable(method: "getUserLibrary", arguments: [], resolvesTo: [DSKCommon.SyncedContent].self)
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
