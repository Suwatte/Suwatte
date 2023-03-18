//
//  JSCContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation
import JavaScriptCore

protocol JSCContextProtocol {
    var runnerClass: JSValue { get }
}

final class JSCContentSource: JSCContextProtocol {
    var info: SourceInfo
    var config: SourceConfig
    var runnerClass: JSValue
    
    required init(path: URL) throws {
        self.runnerClass = try Self.build(for: path)
        guard let dictionary = runnerClass.forProperty("info") else {
            throw DSK.Errors.RunnerInfoInitFailed
        }
        self.info = try SourceInfo(value: dictionary)
        self.config = info.config ?? .init()
    }
    
}



typealias JSCC = JSCContentSource




// MARK: - Paths

private extension JSCC {
    static var commonsPath: URL {
        FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Daisuke", isDirectory: true)
            .appendingPathComponent("common.js")
    }
    
    static var bridgePath: URL {
        Bundle
            .main
            .url(forResource: "Bridge", withExtension: "js")!
    }
}

extension JSCC {
    static func  build(`for` path: URL) throws -> JSValue {
        // Generate New Context
        let context = SourceManager.shared.newJSCContext()
        
        // Evaluate Commons Script
        var content = try String(contentsOf: Self.commonsPath, encoding: .utf8)
        _ = context.evaluateScript(content)
        
        // Inject Handlers
        SourceManager.shared.add(class: JSCC.LogHandler.self, name: "LogHandler", context: context)
        SourceManager.shared.add(class: JSCC.StoreHandler.self, name: "StoreHandler", context: context)
        SourceManager.shared.add(class: DSK.NetworkClient.self, name: "NetworkClient", context: context)
        
        // Evalutate Runner Script
        content = try String(contentsOfFile: path.relativePath, encoding: String.Encoding.utf8)
        _ = context.evaluateScript(content)
        
        // Evaluate Bridge Script
        content = try String(contentsOf: Self.bridgePath, encoding: .utf8)
        _ = context.evaluateScript(content)
        
        guard let runner = context.daisukeRunner(), runner.isObject else {
            throw DSK.Errors.RunnerClassInitFailed
        }
        
        return runner
    }
}

// MARK: - JS Method Callers
extension JSCContentSource {
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
    
    func callContextMethod<T: Decodable>(method: String, arguments: [Any]? = nil, resolvesTo _: T.Type) async throws -> T {
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
