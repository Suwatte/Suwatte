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

extension DataManager {
    func saveRunnerList(_ data: RunnerList, at url: URL) {
        let realm = try! Realm()
        let obj = StoredRunnerList()
        obj.listName = data.listName
        obj.url = url.absoluteString
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func deleteRunner(_ id: String) {
        let realm = try! Realm()

        let results = realm.objects(StoredRunnerObject.self).where { $0.id == id }
        try! realm.safeWrite {
            results.forEach { runner in
                runner.isDeleted = true
            }
        }
    }

    func getRunner(_ id: String) -> StoredRunnerObject? {
        let realm = try! Realm()
        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id }
            .first
    }

    func saveRunner(_ runner: JSCRunner, listURL: URL? = nil, url: URL) {
        let realm = try! Realm()

        let obj = realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == runner.id && !$0.isDeleted }
            .first ?? StoredRunnerObject()

        let info = runner.info
        try! realm.safeWrite {
            obj.name = info.name
            if obj.id.isEmpty {
                obj.id = info.id
            }
            obj.version = info.version
            obj.enabled = true
            obj.environment = runner.environment
            obj.isBrowsePageLinkProvider = runner.intents.browsePageLinkProvider
            obj.isLibraryPageLinkProvider = runner.intents.libraryPageLinkProvider
            obj.isDeleted = false
            if let listURL {
                obj.listURL = listURL.absoluteString
            }

            if obj.executable == nil || url.exists {
                obj.executable = CreamAsset.create(object: obj, propName: StoredRunnerObject.RUNNER_KEY, url: url)
            }
            if let thumbnail = info.thumbnail {
                if thumbnail.contains("http") {
                    if URL(string: thumbnail) != nil {
                        obj.thumbnail = thumbnail
                    }
                } else if let listURL {
                    let path = listURL.appendingPathComponent("assets").appendingPathComponent(thumbnail)
                    obj.thumbnail = path.absoluteString
                }
            }
            realm.add(obj, update: .modified)
        }
    }

    func getRunnerExecutable(id: String) -> URL? {
        let realm = try! Realm()

        let target = realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id && !$0.isDeleted }
            .first
        return target?.executable?.filePath
    }

    func getSavedAndEnabledSources() -> Results<StoredRunnerObject> {
        let realm = try! Realm()

        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == .source }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
    }

    func getLibraryPageProviders() -> [StoredRunnerObject] {
        let realm = try! Realm()

        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.isLibraryPageLinkProvider && $0.enabled && !$0.isDeleted }
            .map { $0.freeze() }
    }

    func getEnabledRunners(for environment: RunnerEnvironment) -> Results<StoredRunnerObject> {
        let realm = try! Realm()

        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == environment }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
    }
}
