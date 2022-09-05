//
//  DSK+ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Combine
import Foundation
import JavaScriptCore

extension DaisukeEngine {
    final class ContentSource: DaisukeRunnerProtocol, ObservableObject, Identifiable {
        var info: DaisukeRunnerInfoProtocol
        internal var runnerClass: JSValue
        var runnerType: DaisukeEngine.RunnerType = .CONTENT_SOURCE
        init(runnerClass: JSValue) throws {
            self.runnerClass = runnerClass

            guard let dictionary = runnerClass.forProperty("info") else {
                throw Errors.RunnerInfoInitFailed
            }
            info = try ContentSourceInfo(value: dictionary)
        }
    }
}

extension DaisukeEngine.ContentSource {
    var id: String {
        info.id
    }

    var name: String {
        info.name
    }

    var version: Double {
        info.version
    }

    var sourceInfo: ContentSourceInfo {
        info as! ContentSourceInfo
    }

    struct ContentSourceInfo: DaisukeRunnerInfoProtocol {
        var id: String
        var name: String
        var version: Double
        var authors: [String]?

        var minSupportedAppVersion: String?
        var website: String
        var supportedLanguages: [String]
        var VXI: String?

        var hasExplorePage: Bool
        var thumbnail: String?

        var authMethod: DSKCommon.AuthMethod?
        var contentSync: Bool?

        var canSync: Bool {
            authMethod != nil && contentSync != nil && contentSync!
        }
    }
}

// MARK: Generic Functions

extension DaisukeEngine.ContentSource {
    func methodExists(method: String) -> Bool {
        runnerClass.hasProperty(method)
    }

    func callOptionalVoidMethod(method: String, arguments: [Any]) async throws {
        try await withUnsafeThrowingContinuation { handler in
            guard runnerClass.hasProperty(method) else {
                handler.resume()
                return
            }

            runnerClass.daisukeCall(method: method, arguments: arguments) { _ in
                handler.resume()
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        } as Void
    }

    func callMethodReturningObject<T: Parsable>(method: String, arguments: [Any], resolvesTo _: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { handler in

            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }

            runnerClass.daisukeCall(method: method, arguments: arguments) { value in
                do {
                    let object = try T(value: value)
                    handler.resume(returning: object)
                } catch {
                    handler.resume(throwing: error)
                }

            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }

    func callMethodReturningDecodable<T: Decodable>(method: String, arguments: [Any], resolvesTo _: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { handler in
            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }
            runnerClass.daisukeCall(method: method, arguments: arguments) { value in

                let str = DaisukeEngine.stringify(val: value)
                guard let str = str else {
                    handler.resume(throwing: DaisukeEngine.Errors.NamedError(name: "Invalid Return", message: "Returned Array Object cannot be converted to JSON String"))
                    return
                }
                do {
                    let jsonData = str.data(using: .utf8)!
                    let output: T = try DaisukeEngine.decode(data: jsonData, to: T.self)
                    handler.resume(returning: output)
                } catch {
                    handler.resume(throwing: error)
                }
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}
