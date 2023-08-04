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

    override init(instance: InstanceInformation, object: JSValue) async throws {
        try await super.init(instance: instance, object: object)
        // Get Config
        if let dictionary = object.forProperty("config"), dictionary.isObject {
            config = try TrackerConfig(value: dictionary)
        }
    }
}
