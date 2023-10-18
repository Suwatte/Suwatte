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
    var directoryTags: [DSKCommon.Property]?

    override init(object: JSValue, for id: String?) async throws {
        try await super.init(object: object, for: id)
        // Get Config
        if let dictionary = runnerClass.forProperty("config"), dictionary.isObject {
            config = try SourceConfig(value: dictionary)
        }
        saveState()
    }
}
