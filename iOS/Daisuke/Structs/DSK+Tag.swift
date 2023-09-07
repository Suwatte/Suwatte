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
    struct Property: Parsable, Identifiable, Hashable {
        var id: String
        var label: String
        var tags: [Tag]
    }

    struct Tag: Parsable, Hashable, Identifiable {
        var id: String
        var label: String
        var nsfw: Bool?
        var image: String?
        var noninteractive: Bool?
        
        
        var isNonInteractive: Bool {
            noninteractive ?? false
        }
    }
}
