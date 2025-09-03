//
//  JSCR+JS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import JavaScriptCore

// MARK: - Asynchronous Call

extension JSCRunner {
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

    func callMethodReturningDecodable<T: Decodable>(method: String, arguments: [Any], resolvesTo _: T.Type) async throws -> T? {
        try await withCheckedThrowingContinuation { handler in
            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }
            runnerClass.daisukeCall(method: method, arguments: arguments) { value in
                if value.isNull || value.isUndefined {
                    handler.resume(returning: nil)
                    return
                }
                let str = DaisukeEngine.stringify(val: value)
                guard let str = str else {
                    handler.resume(throwing: DaisukeEngine.Errors.NamedError(name: "Invalid Return", message: "Returned Array Object cannot be converted to JSON String"))
                    return
                }
                do {
                    let jsonData = str.data(using: .utf8, allowLossyConversion: false)!
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
                    let jsonData = str.data(using: .utf8, allowLossyConversion: false)!
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

    func callContextMethod<T: Decodable>(method: String, arguments _: [Any]? = nil, resolvesTo _: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { handler in
            runnerClass.context!.evaluateScript(method).daisukeCall { value in
                let str = DaisukeEngine.stringify(val: value)
                guard let str = str else {
                    handler.resume(throwing: DaisukeEngine.Errors.NamedError(name: "Invalid Return", message: "Returned Array Object cannot be converted to JSON String"))
                    return
                }
                do {
                    let jsonData = str.data(using: .utf8, allowLossyConversion: false)!
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

// MARK: - Synchronous Call

extension JSCRunner {
    func synchronousCall<T: Decodable>(method: String, arguments: [Any]) throws -> T {
        guard runnerClass.hasProperty(method) else {
            throw DaisukeEngine.Errors.MethodNotFound(name: method)
        }

        let result = runnerClass.invokeMethod(method, withArguments: arguments)
        let error = runnerClass.context!.exception

        // Error Occured in Execution
        if let error {
            throw DaisukeEngine.Errors.nativeError(for: error)
        }

        guard let result, let str = DaisukeEngine.stringify(val: result) else {
            throw DSK.Errors.ObjectConversionFailed
        }

        let jsonData = str.data(using: .utf8, allowLossyConversion: false)!
        let output: T = try DaisukeEngine.decode(data: jsonData, to: T.self)
        return output
    }
}
