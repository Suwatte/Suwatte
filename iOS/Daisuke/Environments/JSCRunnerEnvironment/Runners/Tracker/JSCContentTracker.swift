//
//  JSCContentTracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import JavaScriptCore

class JSCContentTracker: JSCRunner {
    var info: RunnerInfo
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
        
    }
    
    var trackerInfo: TrackerInfo {
        info as! TrackerInfo
    }
}
