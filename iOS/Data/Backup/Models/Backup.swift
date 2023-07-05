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
    
    var readLater: [ReadLater]?
    var progressMarkers: [ProgressMarker]?
    
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

