//
//  JSCContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//
import Foundation
import JavaScriptCore

class JSCContentSource: JSCRunner, Equatable {
    static func == (lhs: JSCContentSource, rhs: JSCContentSource) -> Bool {
        lhs.info.id == rhs.info.id
    }
    
    var info: RunnerInfo
    let intents: RunnerIntents
    var runnerClass: JSValue
    let environment: RunnerEnvironment = .tracker
    var config: SourceConfig?

    required init(value: JSValue) throws {
        self.runnerClass = value
        let ctx = runnerClass.context
        // Prepare Runner Info
        guard let ctx, let dictionary = runnerClass.forProperty("info"), dictionary.isObject else {
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
        if let dictionary = runnerClass.forProperty("config"), dictionary.isObject {
            self.config = try SourceConfig(value: dictionary)
        }
        
        saveState()
    }
    
    var sourceInfo: SourceInfo {
        info as! SourceInfo
    }
}

typealias JSCC = JSCContentSource
typealias AnyContentSource = JSCC


extension JSCC {
    var cloudflareResolutionURL: URL? {
        config?.cloudflareResolutionURL.flatMap(URL.init(string:)) ?? URL.init(string: sourceInfo.website)
    }
    
    func saveState() {
        UserDefaults.standard.set(intents.imageRequestHandler, forKey: STTKeys.RunnerOverridesImageRequest(id))
    }
}


