//
//  Backup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

struct Backup: Codable {
    var lists: [StoredRunnerList]?
    var runners: [StoredRunnerObject]?

    var library: [CodableLibraryEntry]?
    var collections: [LibraryCollection]?
    var markers: [OutdatedMarker]?
    var progressMarkers: [ProgressMarker]?

    var date: Date = .init()
    var appVersion: String = Bundle.main.releaseVersionNumber ?? "UNKNOWN"
    var schemaVersion: Int = SCHEMA_VERSION

    static func load(from url: URL) throws -> Backup {
        let json = try Data(contentsOf: url)
        return try DaisukeEngine.decode(data: json, to: Backup.self)
    }

    func encoded() throws -> Data {
        try DaisukeEngine.encode(value: self)
    }
}
