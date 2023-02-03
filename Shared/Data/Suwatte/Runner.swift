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
    var hosted: Bool?
}

struct Runner: Codable, Hashable {
    var id: String
    var name: String
    var version: Double
    var website: String
    var supportedLanguages: [String]
    var path: String
    
    var authors: [String]?
    var thumbnail: String?
    var nsfw: Bool?
    var minSupportedAppVersion: String?
}

final class StoredRunnerList: Object, ObjectKeyIdentifiable {
    @Persisted var listName: String?
    @Persisted(primaryKey: true) var url: String
    @Persisted var hosted: Bool = false
}

final class StoredRunnerObject: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var listURL: String?
    @Persisted var name: String
    @Persisted var thumbnail: String?
    @Persisted var order: Int
    @Persisted var dateAdded: Date = .init()
    @Persisted var hosted: Bool = false
    @Persisted var info: String?
}

extension DataManager {
    func saveRunnerList(_ data: RunnerList, at url: URL) {
        let realm = try! Realm()
        let obj = StoredRunnerList()
        obj.listName = data.listName
        obj.url = url.absoluteString
        obj.hosted = data.hosted ?? false
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func saveRunnerInfomation(runner: Runner, at url: URL, hosted: Bool = false) {
        let realm = try! Realm()
        let obj = StoredRunnerObject()

        
        obj.id = runner.id
        obj.listURL = url.absoluteString
        obj.name = runner.name
        obj.hosted = hosted
        obj.order = getRunnerInfomation(id: runner.id)?.order ?? realm.objects(StoredRunnerObject.self).count + 1
        
        if let thumbnail = runner.thumbnail {
            obj.thumbnail = url
                .appendingPathComponent("assets")
                .appendingPathComponent(thumbnail)
                .absoluteString
        }
            
        try! realm.safeWrite {
            realm.add(obj, update: .all)
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

    func getHostedRunners() -> Results<StoredRunnerObject> {
        let realm = try! Realm()
        return realm
            .objects(StoredRunnerObject.self)
            .where { $0.hosted == true && $0.listURL != nil && $0.info != nil }
    }
}
