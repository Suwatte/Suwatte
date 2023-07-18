//
//  JSCContentTracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import JavaScriptCore

struct TrackerInfo: RunnerInfo {
    var id: String
    var name: String
    var version: Double
    var minSupportedAppVersion: String?
    var thumbnail: String?
    var website: String
}


struct TrackerConfig: Parsable {
    let linkKeys: [String]?
}

class JSCContentTracker: NSObject, JSCRunner  {
    var configCache: [String : DSKCommon.DirectoryConfig] = [:]
    
    var directoryConfig: DSKCommon.DirectoryConfig?
    
    
    var info: RunnerInfo
    var config: TrackerConfig?
    let intents: RunnerIntents
    var runnerClass: JSValue
    let environment: RunnerEnvironment = .tracker
    
    
    required init(value: JSValue) throws {
        self.runnerClass = value
        let ctx = runnerClass.context
        // Prepare Runner Info
        guard let ctx, let dictionary = runnerClass.forProperty("info"), dictionary.isObject else {
            throw DSK.Errors.RunnerInfoInitFailed
        }

        self.info = try TrackerInfo(value: dictionary)

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
            self.config = try TrackerConfig(value: dictionary)
        }
        
        super.init()
        saveState()
    }
    
    var trackerInfo: TrackerInfo {
        info as! TrackerInfo
    }
    
    var links: [String] {
        let def = config?.linkKeys ?? []
        return def.appending(id)
    }
}
