//
//  DSK+Search.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine.Structs {
    struct SearchRequest: Parsable, Hashable, Codable {
        var query: String?
        var page: Int = 1
        var includedTags: [String] = []
        var excludedTags: [String] = []
        var sort: SortOption?

        static var defaultReq: Self {
            .init()
        }
    }

    struct SortOption: Parsable, Identifiable, Hashable, Codable {
        var label: String
        var id: String
    }

    struct PagedResult: Parsable, Hashable {
        var results: [Highlight]
        var page: Int
        var isLastPage: Bool
        var totalResultCount: Int?
    }
}
