//
//  Backup+LibraryEntry.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension LibraryEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, updateCount, lastUpdated, lastOpened, dateAdded, lastRead, collections, flag
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        content = try? container.decode(StoredContent.self, forKey: .content)
        updateCount = try container.decode(Int.self, forKey: .updateCount)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        lastRead = try container.decode(Date.self, forKey: .lastRead)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        collections = try container.decode(List<String>.self, forKey: .collections)
        lastOpened = try container.decode(Date.self, forKey: .lastOpened)
        flag = try container.decode(LibraryFlag.self, forKey: .flag)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(updateCount, forKey: .updateCount)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(lastRead, forKey: .lastRead)
        try container.encode(collections, forKey: .collections)
        try container.encode(flag, forKey: .flag)
        try container.encode(lastOpened, forKey: .lastOpened)
    }
}

extension DataManager {
    func BUResetLibraryEntries(_: [LibraryEntry]) {
        let realm = try! Realm()

        try! realm.safeWrite {
            // Add new objects
        }
    }
}
