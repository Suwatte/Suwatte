//
//  STT+JSValue.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-14.
//

import Foundation
import JavaScriptCore

extension JSContext {
    func daisukeRunner() -> JSValue? {
        return evaluateScript("(function(){ return RunnerObject })()")
    }
}

extension JSValue {
    func daisukeCall(method: String? = nil, arguments: [Any] = [], onSuccess: @escaping (JSValue) throws -> Void, onFailure: @escaping (Error) -> Void) {
        // Rejector Block
        let rejector: @convention(block) (JSValue) -> Void = {
            errorValue in

            onFailure(DaisukeEngine.Errors.nativeError(for: errorValue))
        }

        // Resolver Block
        let resolver: @convention(block) (JSValue) -> Void = {
            value in
            do {
                try onSuccess(value)

            } catch {
                onFailure(error)
            }
        }

        var promise: JSValue?

        if let method = method {
            promise = invokeMethod(method, withArguments: arguments)
        } else {
            promise = call(withArguments: arguments)
        }

        guard let promise = promise else {
            onFailure(DaisukeEngine.Errors.NamedError(name: "[Method Error]", message: "Method Call Returned Null"))
            return
        }

        guard promise.hasProperty("then") else {
            if let exception = context.exception {
                rejector(exception)
                return
            }
            do {
                try onSuccess(promise)
            } catch {
                onFailure(error)
            }

            return
        }

        // Async Method
        promise.invokeMethod("then", withArguments: [
            JSValue(object: resolver, in: context) as Any,
        ])

        promise.invokeMethod("catch", withArguments: [
            JSValue(object: rejector, in: context) as Any,
        ])
    }
}
