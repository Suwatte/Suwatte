//
//  JSCRunner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-06.
//

import Foundation
import JavaScriptCore

protocol JSCContextProtocol {
    var runnerClass: JSValue { get }
}

protocol DaisukeInterface: Codable, Hashable, Identifiable {}

@objc protocol JSObjectProtocol: JSExport {
    var setThisValue: (@convention(block) (JSValue) -> Void)? { get }
}

class JSObject: NSObject, JSObjectProtocol {
    var this: JSManagedValue?
    
    override init() {
        super.init()
    }
    
    var setThisValue: (@convention(block) (JSValue) -> Void)? {
        return { [unowned self] (value: JSValue) in
            self.this = JSManagedValue(value: value)
        }
    }
    
    func getRunnerID() throws -> String {
        guard let runner = this?.value.context.daisukeRunner() else {
            throw DaisukeEngine.Errors.RunnerNotFoundOnContainedObject
        }
        
        guard let id = runner.forProperty("info")?.forProperty("id")?.toString() else {
            throw DaisukeEngine.Errors.UnableToFetchRunnerIDInContainedObject
        }
        
        return id
    }
}

// MARK: - Runner Info Model
protocol RunnerInfo: Parsable {
    var id: String { get }
    var name: String { get }
    var version: Double { get }
    var minSupportedAppVersion: String? { get }
    var thumbnail: String? { get }
}

// MARK: - Runner Intents
struct RunnerIntents: Parsable {
    let preferenceMenuBuilder: Bool
    let authenticatable: Bool
    let authenticationMethod: AuthenticationMethod?
    let basicAuthLabel: BasicAuthenticationUIIdentifier?
    let chapterEventHandler: Bool
    let contentEventHandler: Bool
    let chapterSyncHandler: Bool
    let librarySyncHandler: Bool
    let imageRequestHandler: Bool
    let explorePageHandler: Bool
    let hasRecommendedTags: Bool
    let hasFullTagList: Bool
    let advancedTracker: Bool
    let libraryTabProvider: Bool
    let browseTabProvider: Bool
    
    enum AuthenticationMethod: String, Codable {
        case webview, basic
    }
    enum BasicAuthenticationUIIdentifier: Int, Codable {
      case EMAIL
      case USERNAME
    }
}

// MARK: - JSC Runner
protocol JSCRunner: JSCContextProtocol {
    var info:  RunnerInfo { get }
    var intents: RunnerIntents { get }
    
    init(executablePath: URL) throws

}

extension JSCRunner {
    var id: String {
        info.id
    }
    
    var name: String {
        info.name
    }
    
    var version: Double {
        info.version
    }
}
// MARK: - Paths

extension JSCRunner {
    static var commonsPath: URL {
        FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Runners", isDirectory: true)
            .appendingPathComponent("common.js")
    }
    
    
    static var messageHandlerFiles: [URL] {
        [
            Bundle.main.url(forResource: "log", withExtension: "js")!,
            Bundle.main.url(forResource: "store", withExtension: "js")!,
            Bundle.main.url(forResource: "network", withExtension: "js")!,
        ]
    }
    
    static var bootstrapFile: URL {
        Bundle.main.url(forResource: "bridge", withExtension: "js")!
    }
}

// MARK: - JS Method Callers
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
