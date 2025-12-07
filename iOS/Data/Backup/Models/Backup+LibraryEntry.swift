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
        case id, content, updateCount, lastUpdated, lastOpened, dateAdded, lastRead, collections, flag, linkedHasUpdates, unreadCount
    }

    static var schemaVersionKey: CodingUserInfoKey {
        return CodingUserInfoKey(rawValue: "schemaVersion")!
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let schemaVersion = decoder.userInfo[Self.schemaVersionKey] as! Int

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if schemaVersion > 15 {
            id = try container.decode(String.self, forKey: .id)
        } else {
            content = try container.decode(StoredContent.self, forKey: .content)
        }
        updateCount = try container.decode(Int.self, forKey: .updateCount)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        lastRead = try container.decode(Date.self, forKey: .lastRead)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        collections = try container.decode(List<String>.self, forKey: .collections)
        lastOpened = try container.decode(Date.self, forKey: .lastOpened)
        flag = try container.decode(LibraryFlag.self, forKey: .flag)
        linkedHasUpdates = try container.decodeIfPresent(Bool.self, forKey: .linkedHasUpdates) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(updateCount, forKey: .updateCount)
        try container.encode(unreadCount, forKey: .unreadCount)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(lastRead, forKey: .lastRead)
        try container.encode(collections, forKey: .collections)
        try container.encode(flag, forKey: .flag)
        try container.encode(lastOpened, forKey: .lastOpened)
        try container.encode(linkedHasUpdates, forKey: .linkedHasUpdates)
    }

    func fillContent(data: [String: [StoredContent]]) {
        content = data[id]?.first
    }
}

struct CodableContent: Codable {
    var id: String
    var sourceId: String
    var contentId: String
    var title: String
    var cover: String

    static func from(content: StoredContent) -> Self {
        .init(id: content.id, sourceId: content.sourceId, contentId: content.contentId, title: content.title, cover: content.cover)
    }
}

struct CodableLibraryEntry: Codable {
    var id: String

    // Update information
    var updateCount: Int
    var lastUpdated: Date

    // Dates
    var dateAdded: Date
    var lastRead: Date = .distantPast
    var lastOpened: Date = .distantPast

    // Collections
    var collections: [String]
    var flag: LibraryFlag
    var unreadCount: Int?

    static func from(entry: LibraryEntry) -> Self {
        .init(
            id: entry.content!.id,
            updateCount: entry.updateCount,
            lastUpdated: entry.lastRead,
            dateAdded: entry.dateAdded,
            collections: entry.collections.toArray(),
            flag: entry.flag,
            unreadCount: entry.unreadCount
        )
    }
}

struct CodableChapter: Codable, Hashable, STTChapter {
    var id: String
    var sourceId: String
    var contentId: String
    var chapterId: String
    var index: Int
    var number: Double
    var volume: Double?
}
