//
//  JSCContentTracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import JavaScriptCore

final class JSCContentTracker: JSCRunner {
    var config: TrackerConfig?

    override init(object: JSValue) async throws {
        try await super.init(object: object)
        // Get Config
        if let dictionary = object.forProperty("config"), dictionary.isObject {
            config = try TrackerConfig(value: dictionary)
        }
    }
}
