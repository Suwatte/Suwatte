//
//  Backup+ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-04.
//

import Foundation
import RealmSwift

extension ProgressMarker: Codable {
    enum Keys: String, CodingKey {
        case id, readChapters, dateRead, lastPageRead, totalPageCount, lastPageOffsetPCT, currentChapter
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        readChapters = try container.decodeIfPresent(MutableSet.self, forKey: .readChapters) ?? .init()
        dateRead = try container.decodeIfPresent(Date.self, forKey: .dateRead)
        lastPageRead = try container.decodeIfPresent(Int.self, forKey: .lastPageRead)
        totalPageCount = try container.decodeIfPresent(Int.self, forKey: .totalPageCount)
        lastPageOffsetPCT = try container.decodeIfPresent(Double.self, forKey: .lastPageOffsetPCT)
        currentChapter = try container.decodeIfPresent(ChapterReference.self, forKey: .currentChapter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(readChapters, forKey: .readChapters)
        try container.encode(dateRead, forKey: .dateRead)
        try container.encode(lastPageRead, forKey: .lastPageRead)
        try container.encode(totalPageCount, forKey: .totalPageCount)
        try container.encode(lastPageOffsetPCT, forKey: .lastPageOffsetPCT)
        try container.encode(currentChapter, forKey: .currentChapter)
    }
}
