//
//  JSCContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//
import Foundation
import JavaScriptCore

class JSCContentSource: NSObject, JSCRunner {
    var configCache: [String : DSKCommon.DirectoryConfig] = [:]
    

    
    static func == (lhs: JSCContentSource, rhs: JSCContentSource) -> Bool {
        lhs.info.id == rhs.info.id
    }
    
    var info: RunnerInfo
    let intents: RunnerIntents
    var runnerClass: JSValue
    let environment: RunnerEnvironment = .source
    var config: SourceConfig?
    
    var directoryConfig: DSKCommon.DirectoryConfig?
    var directoryTags: [DSKCommon.Property]?

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
        super.init()
        saveState()
    }
    
    var sourceInfo: SourceInfo {
        info as! SourceInfo
    }
}

typealias JSCCS = JSCContentSource
typealias AnyContentSource = JSCCS


extension JSCCS {
    var cloudflareResolutionURL: URL? {
        config?.cloudflareResolutionURL.flatMap(URL.init(string:)) ?? URL.init(string: sourceInfo.website)
    }
    
}


extension JSCCS {
    func ablityNotDisabled(_ path: KeyPath<SourceConfig, Bool?>) -> Bool {
        !(self.config?[keyPath: path] ?? false)
    }
}
