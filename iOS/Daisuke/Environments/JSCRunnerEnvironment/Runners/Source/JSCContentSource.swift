//
//  JSCContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//
import Foundation
import JavaScriptCore

final class JSCContentSource: JSCRunner, ContentSource {
    var config: SourceConfig?
    internal var directoryTags: [DSKCommon.Property]?

    override init(instance: InstanceInformation, object: JSValue) async throws {
        try await super.init(instance: instance, object: object)
        // Get Config
        if let dictionary = runnerClass.forProperty("config"), dictionary.isObject {
            config = try SourceConfig(value: dictionary)
        }
    }
}
