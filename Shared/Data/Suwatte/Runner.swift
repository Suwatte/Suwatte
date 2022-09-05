//
//  Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import Foundation
import RealmSwift

struct RunnerList: Codable, Hashable {
    var listName: String?
    var runners: [Runner]
}

struct Runner: Codable, Hashable {
    var id: String
    var name: String
    var version: Double
    var authors: [String]?
    var minSupportedAppVersion: String?
    var type: DaisukeEngine.RunnerType
    var website: String?
    var supportedLanguages: [String]?
    var primarilyAdultContent: Bool?
    var path: String
    var thumbnail: String?

    func getThumbURL(in list: String) -> URL? {
        guard let thumbnail = thumbnail else {
            return nil
        }

        // Thumbnail is URL
        if let url = URL(string: thumbnail), url.isHTTP {
            return url
        }

        // Thumbnail is Asset Object
        guard let url = URL(string: list)?.sttBase else {
            return nil
        }

        return url
            .appendingPathComponent("assets")
            .appendingPathComponent(thumbnail)
    }
}

final class StoredRunnerList: Object, ObjectKeyIdentifiable {
    @Persisted var listName: String?
    @Persisted(primaryKey: true) var url: String
}

final class StoredRunnerObject: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var listURL: String?
    @Persisted var name: String
    @Persisted var thumbnail: String?

    func thumb() -> URL? {
        guard let thumbnail = thumbnail else {
            return nil
        }

        // Thumbnail is URL
        if let url = URL(string: thumbnail), url.isHTTP {
            return url
        }

        // Thumbnail is Asset Object
        guard let url = URL(string: listURL ?? "")?.sttBase else {
            return nil
        }

        return url
            .appendingPathComponent("assets")
            .appendingPathComponent(thumbnail)
    }
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

    func saveRunnerInfomation(runner: Runner, at url: URL) {
        let realm = try! Realm()
        let obj = StoredRunnerObject()

        obj.id = runner.id
        obj.listURL = url.sttBase?.absoluteString
        obj.name = runner.name
        obj.thumbnail = runner.thumbnail

        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func getRunnerInfomation(id: String) -> StoredRunnerObject? {
        let realm = try! Realm()

        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id }
            .first
    }

    func removeRunnerInformation(id: String) {
        let realm = try! Realm()

        let targets = realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id }

        try! realm.safeWrite {
            realm.delete(targets)
        }
    }
}
