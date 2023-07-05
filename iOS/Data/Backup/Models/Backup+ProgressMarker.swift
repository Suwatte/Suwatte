//
//  Backup+ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-04.
//

import Foundation
import RealmSwift

extension ChapterReference: Codable {
    enum Keys: String, CodingKey {
        case id, chapterId, number, volume, content
    }
    
    convenience init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        chapterId = try container.decode(String.self, forKey: .chapterId)
        content = try container.decodeIfPresent(StoredContent.self, forKey: .content)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        number = try container.decode(Double.self, forKey: .number)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(chapterId, forKey: .chapterId)
        try container.encode(number, forKey: .number)
        try container.encode(volume, forKey: .volume)
        try container.encode(content, forKey: .content)
    }
    
}


extension ProgressMarker: Codable {
    enum Keys: String, CodingKey {
        case id, readChapters, dateRead, lastPageRead, totalPageCount, lastPageOffset, currentChapter
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        readChapters = try container.decodeIfPresent(MutableSet.self, forKey: .readChapters) ?? .init()
        dateRead = try container.decodeIfPresent(Date.self, forKey: .dateRead)
        lastPageRead = try container.decodeIfPresent(Int.self, forKey: .lastPageRead)
        totalPageCount = try container.decodeIfPresent(Int.self, forKey: .totalPageCount)
        lastPageOffset = try container.decodeIfPresent(Double.self, forKey: .lastPageOffset)
        currentChapter = try container.decodeIfPresent(ChapterReference.self, forKey: .currentChapter)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(readChapters, forKey: .readChapters)
        try container.encode(dateRead, forKey: .dateRead)
        try container.encode(lastPageRead, forKey: .lastPageRead)
        try container.encode(totalPageCount, forKey: .totalPageCount)
        try container.encode(lastPageOffset, forKey: .lastPageOffset)
        try container.encode(currentChapter, forKey: .currentChapter)
    }
}
