//
//  Engine+JSC.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import JavaScriptCore

// MARK: - Bootstrap

extension DaisukeEngine {
    private func newJSCContext() -> JSContext {
        JSContext(virtualMachine: vm)!
    }

    private func add(class cls: AnyClass, name: String, context: JSContext) {
        let constructorName = "__constructor__\(name)"

        let constructor: @convention(block) () -> NSObject = {
            let cls = cls as! NSObject.Type
            return cls.init()
        }

        context.setObject(unsafeBitCast(constructor, to: AnyObject.self),
                          forKeyedSubscript: constructorName as NSCopying & NSObjectProtocol)

        let script = "function \(name)() " +
            "{ " +
            "   var obj = \(constructorName)(); " +
            "   obj.setThisValue(obj); " +
            "   return obj; " +
            "} "

        context.evaluateScript(script)
    }

    func bootstrapJSCRunner(_ scriptURL: URL) throws -> JSValue {
        // Generate New Context
        let context = newJSCContext()

        // Required File Routes
        let commonsPath = FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Runners", isDirectory: true)
            .appendingPathComponent("common.js")

        let messageHandlerFiles = [
            Bundle.main.url(forResource: "log", withExtension: "js")!,
            Bundle.main.url(forResource: "store", withExtension: "js")!,
            Bundle.main.url(forResource: "network", withExtension: "js")!,
        ]

        let bootstrapFile = Bundle.main.url(forResource: "bridge", withExtension: "js")!

        // Declare Intial ID
        context.globalObject.setValue(scriptURL.fileName, forProperty: "IDENTIFIER")
        // Evaluate Commons Script
        var content = try String(contentsOf: commonsPath, encoding: .utf8)
        _ = context.evaluateScript(content)

        // Inject Handlers
        add(class: JSCHandler.LogHandler.self, name: "LogHandler", context: context)
        add(class: JSCHandler.StoreHandler.self, name: "StoreHandler", context: context)
        add(class: JSCHandler.NetworkHandler.self, name: "NetworkHandler", context: context)

        // JSExports
        JSCTimer.register(context: context)

        // Evaluate Message Handler Scripts
        for url in messageHandlerFiles {
            content = try String(contentsOf: url, encoding: .utf8)
            _ = context.evaluateScript(content)
        }

        // Evalutate Runner Script
        content = try String(contentsOf: scriptURL, encoding: .utf8)
        _ = context.evaluateScript(content)

        let error = context.exception
        if let error {
            Logger.shared.error("Error Occured While Evaluating Runner Script", "Engine BootStrap JSCRunner")
            throw DaisukeEngine.Errors.nativeError(for: error)
        }
        // Evaluate Bootstrap Script
        content = try String(contentsOf: bootstrapFile, encoding: .utf8)
        _ = context.evaluateScript(content)

        let runner = context.daisukeRunner()
        guard let runner, runner.isObject else {
            throw DSK.Errors.RunnerClassInitFailed
        }

        return runner
    }
}

extension DaisukeEngine {
    func startJSCRunner(with url: URL, for id: String?) async throws -> AnyRunner {
        let runnerObject = try bootstrapJSCRunner(url)

        // Get Runner Environment
        let environment = runnerObject
            .context!
            .evaluateScript("(function(){ return RunnerEnvironment })()")
            .toString()
            .flatMap(DSKCommon.RunnerEnvironment.init(rawValue:)) ?? .unknown
        var runner: JSCRunner? = nil
        switch environment {
        case .source:
            runner = try await JSCContentSource(object: runnerObject, for: id)
        case .tracker:
            runner = try await JSCContentTracker(object: runnerObject, for: id)
        default:
            break
        }

        guard let runner else {
            throw DSK.Errors.NamedError(name: "Engine", message: "Failed to recognize runner environment.")
        }

        return runner
    }
}
