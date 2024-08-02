//
//  Backup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

struct Backup: Codable {
    var collections: [LibraryCollection]?
    var lists: [StoredRunnerList]?
    var runners: [StoredRunnerObject]?
    var storedContents: [StoredContent]?
    var library: [LibraryEntry]?
    var markers: [OutdatedMarker]?
    var progressMarkers: [ProgressMarker]?

    var date: Date = .init()
    var appVersion: String = Bundle.main.releaseVersionNumber ?? "UNKNOWN"
    var schemaVersion: Int = SCHEMA_VERSION

    static let schemaVersionUserInfoKey = CodingUserInfoKey(rawValue: "schemaVersion")!

    static func load(from url: URL) throws -> Backup {
        let json = try Data(contentsOf: url)
        let version = try DaisukeEngine.decode(data: json, to: BasicBackupScheme.self)
        return try DaisukeEngine.decode(data: json, to: Backup.self, dateFormatter: nil, userInfo: [schemaVersionUserInfoKey: version.schemaVersion])
    }

    func encoded() throws -> Data {
        try DaisukeEngine.encode(value: self)
    }
}

struct BasicBackupScheme: Codable {
    var schemaVersion: Int
}
