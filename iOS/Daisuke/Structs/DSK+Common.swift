//
//  DSK+Common.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-02.
//

import Foundation

extension DSKCommon {
    struct JSCommon: Codable {
        var version: String
    }
    
    enum RunnerEnvironment: String, Decodable {
        case unknown, source, tracker, plugin
    }
}

extension DSKCommon {
    struct User: Parsable, Hashable {
        var id: String
        var username: String
        var avatar: String?
        var info: [String]?
    }
}

