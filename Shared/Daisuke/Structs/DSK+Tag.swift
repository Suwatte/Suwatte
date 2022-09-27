//
//  DSK+Tag.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine {
    struct Structs {}
}

extension DaisukeEngine.Structs {
    struct Filter: Parsable, Identifiable, Hashable {
        var id: String
        var property: Property
        var canExclude: Bool
    }

    struct Property: Parsable, Identifiable, Hashable {
        var id: String
        var label: String
        var tags: [Tag]
    }
    
    
    struct NonInteractiveProperty: Parsable, Hashable, Identifiable {
        var id: String
        var label: String
        var tags: [String]
    }

    struct Tag: Parsable, Hashable, Identifiable {
        var id: String
        var label: String
        var adultContent: Bool
        var imageUrl: String?
    }
}
