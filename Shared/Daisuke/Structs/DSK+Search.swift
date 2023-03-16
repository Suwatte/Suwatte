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
        var page: Int? = 1
        var sort: String?
        var filters: [PopulatedFilter]?

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

    struct Filter: Parsable, Identifiable, Hashable {
        var id: String
        var title: String
        var type: FilterType
        var subtitle: String?
        var label: String?
        var options: [Option]?
    }

    struct PopulatedFilter: Parsable, Identifiable, Hashable {
        var id: String
        var bool: Bool?
        var text: String?
        var selected: String?
        var included: [String]?
        var excluded: [String]?
    }

    enum FilterType: Int, Codable {
        case toggle, select, multiselect, excludableMultiselect, text, info
    }
}
