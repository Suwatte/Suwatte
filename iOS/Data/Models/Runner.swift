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
    case unknown, tracker, source, plugin

    var description: String {
        switch self {
        case .tracker:
            return "Trackers"
        case .source:
            return "Content Sources"
        case .plugin:
            return "Plugins"
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
    var nsfw: Bool?
    var environment: RunnerEnvironment = .unknown
    var thumbnail: String?
    var minSupportedAppVersion: String?
}

final class StoredRunnerList: Object, ObjectKeyIdentifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted var listName: String?
    @Persisted(primaryKey: true) var url: String
    @Persisted var hosted: Bool = false
    @Persisted var isDeleted = false
}

final class StoredRunnerObject: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
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

    static let RUNNER_KEY = "bundle"
    @Persisted var executable: CreamAsset?
}

final class RunnerInstance: Object, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var instanceID = UUID().uuidString
    @Persisted var instanceOf: StoredRunnerObject?
    @Persisted var preferredName: String?
    @Persisted var isDeleted = false
    
    var name: String {
        preferredName ?? instanceOf?.name ?? ""
    }
}
