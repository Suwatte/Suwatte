//
//  Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import Foundation
import IceCream
import RealmSwift

enum RunnerEnvironment: String, PersistableEnum, Codable, Hashable {
    case unknown, tracker, source

    var description: String {
        switch self {
        case .tracker:
            return "Trackers"
        case .source:
            return "Sources"
        case .unknown:
            return "Unknown"
        }
    }
}

struct RunnerList: Codable, Hashable {
    var listName: String?
    var runners: [Runner]
}

struct Runner: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var version: Double
    var website: String?
    var supportedLanguages: [String]?
    var path: String
    let rating: CatalogRating?
    var environment: RunnerEnvironment = .unknown
    var thumbnail: String?
    var minSupportedAppVersion: String?
}

final class StoredRunnerList: Object, ObjectKeyIdentifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted var listName: String?
    @Persisted(primaryKey: true) var url: String
    @Persisted var isDeleted = false
}

final class StoredRunnerObject: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var parentRunnerID: String?
    @Persisted var name: String
    @Persisted var version: Double
    @Persisted var environment: RunnerEnvironment = .unknown

    @Persisted var dateAdded: Date = .init()
    @Persisted var enabled: Bool

    @Persisted var listURL: String
    @Persisted var thumbnail: String
    @Persisted var isDeleted = false

    @Persisted var isLibraryPageLinkProvider = false
    @Persisted var isBrowsePageLinkProvider = false
    @Persisted var isInstantiable = false

    static let RUNNER_KEY = "bundle"
    @Persisted var executable: CreamAsset?
}
