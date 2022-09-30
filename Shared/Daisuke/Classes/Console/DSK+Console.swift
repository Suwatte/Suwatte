//
//  DSK+Console.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-14.
//

import Foundation
import JavaScriptCore

extension JSObject {
    func getRunnerID() throws -> String {
        guard let runner = this?.value.context.daisukeRunner() else {
            throw DaisukeEngine.Errors.RunnerNotFoundOnContainedObject
        }

        guard let id = runner.forProperty("info")?.forProperty("id")?.toString() else {
            throw DaisukeEngine.Errors.UnableToFetchRunnerIDInContainedObject
        }

        return id
    }
}

extension DSK {
    func consoleLog(message: JSValue?, options: JSValue) {
        var messages = options.toArray() ?? []
        if let message = message?.toObject() {
            messages.insert(message, at: 0)
        }
        
        var context = "[Daisuke]"
        let runner = options.context.daisukeRunner()
        let runnerId = runner?.forProperty("info")?.forProperty("id")?.toString() ?? "UNKNOWN RUNNER"
        context += " [\(runnerId)] "
        context += messages.map({ "\($0)" }).joined(separator: " ")
        Logger.shared.log(context)
    }
}
