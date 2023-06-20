//
//  Backup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

struct Backup: Codable {
    var library: [LibraryEntry]?
    var collections: [LibraryCollection]?
    var bookmarks: [Bookmark]?
    var savedForLater: [ReadLater]?
    var content: [StoredContent]?

    var sources: [String]?
    var date: Date = .init()

    var appVersion: String = Bundle.main.releaseVersionNumber ?? "UNKNOWN"
    var schemaVersion: Int = SCHEMA_VERSION

    var runnerLists: [StoredRunnerList]?
    var runners: [StoredRunnerObject]?
    static func load(from url: URL) throws -> Backup {
        let json = try Data(contentsOf: url)
        let version = try DaisukeEngine.decode(data: json, to: BasicBackUpScheme.self)
        if version.schemaVersion <= 3 { // Pre ISO 8601 Change
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            return try DaisukeEngine.decode(data: json, to: Backup.self, dateFormatter: dateFormatter)
        } else {
            return try DaisukeEngine.decode(data: json, to: Backup.self)
        }
    }

    func encoded() throws -> Data {
        try DaisukeEngine.encode(value: self)
    }
}

struct BasicBackUpScheme: Codable {
    var schemaVersion: Int
}

extension DataManager {
    func getAllLibraryObjects() -> Backup {
        let realm = try! Realm()

        let libraryEntries = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil }

        let librarySources = Set(libraryEntries.compactMap { $0.content?.sourceId })
        let libraryIds = Set(libraryEntries.compactMap { $0.content?.contentId })

        let collections = realm
            .objects(LibraryCollection.self)

        let bookmarks = realm
            .objects(Bookmark.self)

        let readLater = realm
            .objects(ReadLater.self)
            .where { $0.content != nil }

        let lists = realm
            .objects(StoredRunnerList.self)

        let runners = realm
            .objects(StoredRunnerObject.self)

        // TODO: Stored OPDS Servers

        var backup = Backup()
        backup.bookmarks = bookmarks.toArray()
        backup.savedForLater = readLater.toArray()
        backup.library = libraryEntries.toArray()
        backup.collections = collections.toArray()
        backup.runnerLists = lists.toArray()
        backup.runners = runners.toArray()

        return backup
    }
}
