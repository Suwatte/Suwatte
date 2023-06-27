//
//  Backup+Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension Bookmark: Codable {
    enum Keys: String, CodingKey {
        case id, page, dateAdded, marker, offset, chapter
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        id = try container.decode(String.self, forKey: .id)
        page = try container.decode(Int.self, forKey: .page)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        verticalOffset = try container.decodeIfPresent(Double.self, forKey: .offset)
//        chapter = try container.decodeIfPresent(StoredChapter.self, forKey: .chapter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

//        try container.encode(chapter, forKey: .chapter)
        try container.encode(id, forKey: .id)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(page, forKey: .page)
        try container.encode(verticalOffset, forKey: .offset)
    }
}
