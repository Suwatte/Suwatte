//
//  JSCRunner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-06.
//

import Foundation
import JavaScriptCore

protocol JSCContextWrapper {
    var runnerClass: JSValue { get }
}

public class JSCRunner: DSKRunner, JSCContextWrapper {
    let runnerClass: JSValue
    let info: RunnerInfo
    let intents: RunnerIntents
    var configCache: [String: DSKCommon.DirectoryConfig] = [:]
    init(object: JSValue) async throws {
        runnerClass = object
        let ctx = runnerClass.context
        // Prepare Runner Info
        guard let ctx, let dictionary = runnerClass.forProperty("info"), dictionary.isObject else {
            throw DSK.Errors.RunnerInfoInitFailed
        }

        info = try RunnerInfo(value: dictionary)

        // Get Intents
        let intents = try ctx
            .evaluateScript("(function(){ return RunnerIntents })()")
            .flatMap { try RunnerIntents(value: $0) }

        guard let intents else {
            throw DSK.Errors.FailedToParseRunnerIntents
        }
        self.intents = intents
        saveState()
    }
}
