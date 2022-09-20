//
//  DSK+Explore.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine.Structs {
    enum CollectionStyle: Int, Codable {
        case NORMAL, INFO, GALLERY, UPDATE_LIST
    }

    struct HighlightCollection: Parsable, Identifiable, Hashable {
        var id: String
        var title: String
        var subtitle: String?
        var style: CollectionStyle
        var request: SearchRequest?
        var highlights: [DaisukeEngine.Structs.Highlight]

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        func toExcerpt() -> CollectionExcerpt {
            .init(id: id, title: title, subtitle: subtitle, style: style, request: request)
        }
    }

    struct CollectionExcerpt: Parsable, Hashable, Identifiable, Encodable {
        var id: String
        var title: String
        var subtitle: String?
        var style: CollectionStyle
        var request: SearchRequest?
    }

    struct ExploreCollection: Parsable, Hashable {
        var title: String?
        var subtitle: String?
        var highlights: [Highlight]
    }
}
