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
        var handle: String
        var displayName: String?
        
        var avatar: String?
        var bannerImage: String?
        
        var info: [String]?
        
        
        var name : String {
            displayName ?? handle
        }
    }
}

