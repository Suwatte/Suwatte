//
//  AL+Genre.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//

import Foundation

extension Anilist {
    struct Tag: Decodable, Hashable {
        var category: String
        var description: String
        var isAdult: Bool
        var name: String
    }

    struct GenreResponse: Decodable {
        var data: NestedVal

        struct NestedVal: Decodable, Hashable {
            var genres: [String]
            var tags: [Tag]
        }
    }
}
