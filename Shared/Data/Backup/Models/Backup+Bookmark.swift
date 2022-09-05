//
//  Backup+Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension Bookmark: Codable {
    enum Keys: String, CodingKey {
        case id, page, dateAdded, marker
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        _id = try container.decode(String.self, forKey: .id)
        page = try container.decode(Int.self, forKey: .page)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        marker = try container.decodeIfPresent(ChapterMarker.self, forKey: .marker)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(marker, forKey: .marker)
        try container.encode(_id, forKey: .id)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(page, forKey: .page)
    }
}
