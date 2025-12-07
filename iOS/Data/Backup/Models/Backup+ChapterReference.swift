//
//  Backup+ChapterReference.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-30.
//

import Foundation
import RealmSwift

extension ChapterReference: Codable {
    enum Keys: String, CodingKey {
        case id, chapterId, number, volume, contentId
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        chapterId = try container.decode(String.self, forKey: .chapterId)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        number = try container.decode(Double.self, forKey: .number)
        contentId = try container.decode(String.self, forKey: .contentId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(chapterId, forKey: .chapterId)
        try container.encode(number, forKey: .number)
        try container.encode(volume, forKey: .volume)
        try container.encode(content!.id, forKey: .contentId)
    }

    func updateFromBackup(data: [String: [StoredContent]]) {
        content = data[contentId!]?.first
    }
}
