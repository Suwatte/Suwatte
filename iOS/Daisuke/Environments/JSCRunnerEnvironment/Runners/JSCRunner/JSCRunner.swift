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

    var customID: String?
    var customName: String?

    init(object: JSValue, for customID: String?) async throws {
        self.customID = customID
        runnerClass = object

        if let customID {
            let actor = await RealmActor.shared()
            customName = await actor.getRunner(customID)?.name
            object.context.evaluateScript("RunnerObject.info.id = '\(customID)';IDENTIFIER = '\(customID)'")
        }

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
