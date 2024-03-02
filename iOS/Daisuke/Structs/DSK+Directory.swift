//
//  DSK+Directory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import AnyCodable
import Foundation

extension DSKCommon {
    enum FilterType: Int, Codable {
        case toggle, select, multiselect, excludableMultiselect, text, info
    }

    struct DirectoryConfig: Parsable, Hashable {
        let sort: Sort?
        let lists: [DSKCommon.Option]?
        let filters: [DirectoryFilter]?
        var searchable: Bool?

        var canSearch: Bool {
            searchable ?? false
        }

        var canFilter: Bool {
            filters != nil && !filters!.isEmpty
        }

        var canSort: Bool {
            sort != nil && !sort!.options.isEmpty
        }

        struct Sort: JSCObject {
            let options: [Option]
            let `default`: DirectoryRequest.SortSelection?
            let canChangeOrder: Bool?
        }
    }

    struct DirectoryFilter: Parsable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let label: String?
        let type: FilterType
        let options: [Option]?
    }

    struct ExcludableMultiSelectProp: Parsable {
        var included: Set<String>
        var excluded: Set<String>
    }

    struct DirectoryRequest: Parsable, Hashable {
        var query: String?
        var page: Int
        var filters: [String: AnyCodable]?
        var tag: RequestTag?
        var listId: String?
        var context: [String: AnyCodable]?
        var configID: String?
        var sort: SortSelection?

        struct RequestTag: Parsable, Hashable {
            var tagId: String
            var propertyId: String
        }

        struct SortSelection: JSCObject {
            let id: String
            var ascending: Bool?
        }
    }

    struct PagedResult: JSCObject {
        var results: [Highlight]
        var isLastPage: Bool
        var totalResultCount: Int?
    }

    struct HighlightCollection: Parsable, Identifiable, Hashable {
        var id: String
        var title: String
        var subtitle: String?
        var request: DirectoryRequest?
        var highlights: [DSKCommon.Highlight]
    }
}
