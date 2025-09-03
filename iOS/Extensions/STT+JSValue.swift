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

        var execution: JSValue?

        if let method = method {
            execution = invokeMethod(method, withArguments: arguments)
        } else {
            execution = call(withArguments: arguments)
        }

        guard let execution = execution else {
            onFailure(DaisukeEngine.Errors.NamedError(name: "[Engine Error]", message: "execution did not return a result."))
            return
        }

        // Method Executed and threw error before we could check for properties
        if execution.isUndefined, let exception = context.exception {
            rejector(exception)
            return
        }

        let isPromise = execution.hasProperty("then")
        if isPromise {
            execution.invokeMethod("then", withArguments: [
                JSValue(object: resolver, in: context) as Any,
            ])

            execution.invokeMethod("catch", withArguments: [
                JSValue(object: rejector, in: context) as Any,
            ])
        } else {
            if let exception = context.exception {
                rejector(exception)
                return
            }
            do {
                try onSuccess(execution)
            } catch {
                onFailure(error)
            }
        }
    }
}
