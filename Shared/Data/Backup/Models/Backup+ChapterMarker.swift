//
//  Backup+ChapterMarekr.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension ChapterMarker: Codable {
    enum Keys: String, CodingKey {
        case id, chapter, lastPageRead, totalPageCount, completed, dateRead, lastPageOffset, last, total
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        chapter = try container.decode(StoredChapter.self, forKey: .chapter)
        _id = try container.decode(String.self, forKey: .id)
        lastPageRead = try (container.decodeIfPresent(Int.self, forKey: .last) ?? container.decode(Int.self, forKey: .lastPageRead))
        totalPageCount = try (container.decodeIfPresent(Int.self, forKey: .total) ?? container.decode(Int.self, forKey: .totalPageCount))
        completed = try container.decode(Bool.self, forKey: .completed)
        dateRead = try container.decodeIfPresent(Date.self, forKey: .dateRead)
        lastPageOffset = try container.decodeIfPresent(Double.self, forKey: .lastPageOffset)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(_id, forKey: .id)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(totalPageCount, forKey: .totalPageCount)
        try container.encode(lastPageRead, forKey: .lastPageRead)
        try container.encode(completed, forKey: .completed)
        try container.encode(dateRead, forKey: .dateRead)
        try container.encode(lastPageOffset, forKey: .lastPageOffset)
    }
}
