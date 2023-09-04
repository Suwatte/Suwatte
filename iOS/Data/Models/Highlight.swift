//
//  Highlight.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-27.
//

import Foundation

struct TaggedHighlight: Identifiable, Hashable {
    var sourceID: String
    var contentID: String
    var title: String
    var coverURL: String

    var cover: URL? {
        URL(string: coverURL)
    }

    init(from highlight: DSKCommon.Highlight, with sourceID: String) {
        self.sourceID = sourceID
        contentID = highlight.contentId
        title = highlight.title
        coverURL = highlight.cover
    }

    var id: String {
        ContentIdentifier(contentId: contentID, sourceId: sourceID).id
    }

    var highlight: DSKCommon.Highlight {
        .init(contentId: contentID, cover: coverURL, title: title)
    }
}
