//
//  JSCContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//
import Foundation
import JavaScriptCore

class JSCContentSource: JSCRunner {
    var info: RunnerInfo
    let intents: RunnerIntents
    var runnerClass: JSValue

    var config: SourceConfig

    required init(executablePath: URL) throws {
        runnerClass = try Self.build(for: executablePath)
        let ctx = runnerClass.context
        
        // Prepare Runner Info
        guard let ctx, let dictionary = runnerClass.forProperty("info") else {
            throw DSK.Errors.RunnerInfoInitFailed
        }
        
        self.info = try SourceInfo(value: dictionary)
        
        // Get Intents
        let intents = try ctx
            .evaluateScript("(function(){ return RunnerIntents })()")
            .flatMap { try RunnerIntents(value: $0) }
        
        guard let intents else {
            throw DSK.Errors.FailedToParseRunnerIntents
        }
        
        self.intents = intents
        
        // Get Config
        guard let dictionary = runnerClass.forProperty("config") else {
            throw DSK.Errors.FailedToParseRunnerConfig
        }
        
        self.config = try SourceConfig(value: dictionary)
    }
    
    var sourceInfo: SourceInfo {
        info as! SourceInfo
    }
}

typealias JSCC = JSCContentSource
typealias AnyContentSource = JSCC



extension JSCC {
    static func build(for path: URL) throws -> JSValue {
        // Generate New Context
        let context = SourceManager.shared.newJSCContext()

        // Evaluate Commons Script
        var content = try String(contentsOf: Self.commonsPath, encoding: .utf8)
        _ = context.evaluateScript(content)

        // Inject Handlers
        SourceManager.shared.add(class: JSCHandler.LogHandler.self, name: "LogHandler", context: context)
        SourceManager.shared.add(class: JSCHandler.StoreHandler.self, name: "StoreHandler", context: context)
        SourceManager.shared.add(class: JSCHandler.NetworkHandler.self, name: "NetworkHandler", context: context)

        // Evalutate Runner Script
        content = try String(contentsOf: path, encoding: .utf8)
        _ = context.evaluateScript(content)

        // Evaluate Bridge Scripts
        for url in Self.bridgeFiles {
            content = try String(contentsOf: url, encoding: .utf8)
            _ = context.evaluateScript(content)
        }

        let runner = context.daisukeRunner()
        guard let runner, runner.isObject else {
            throw DSK.Errors.RunnerClassInitFailed
        }

        return runner
    }
}


extension JSCC {
    var cloudflareResolutionURL: URL? {
        config.cloudflareResolutionURL.flatMap(URL.init(string:)) ?? URL.init(string: sourceInfo.website)
    }
}


