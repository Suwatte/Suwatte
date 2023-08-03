//
//  Realm+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift
import IceCream

extension RealmActor {
    func saveRunnerList(_ data: RunnerList, at url: URL) async {
        let obj = StoredRunnerList()
        obj.listName = data.listName
        obj.url = url.absoluteString
        try! await realm.asyncWrite {
            realm.add(obj, update: .modified)
        }
    }

    func deleteRunner(_ id: String) async {
        let results = realm.objects(StoredRunnerObject.self).where { $0.id == id }
        try! await realm.asyncWrite {
            results.forEach { runner in
                runner.isDeleted = true
            }
        }
    }

    func getRunner(_ id: String) -> StoredRunnerObject? {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id }
            .first
    }

    func saveRunner(_ runner: JSCRunner, listURL: URL? = nil, url: URL) async {
        let obj = realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == runner.id && !$0.isDeleted }
            .first ?? StoredRunnerObject()

        let info = runner.info
        try! await realm.asyncWrite {
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
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.id == id && !$0.isDeleted }
            .first?
            .executable?
            .filePath
    }
    
    func getAllRunnerNames() -> [String:String] {
        let kvSq = realm
            .objects(StoredRunnerObject.self)
            .map { ($0.id, $0.name) }
        
        return Dictionary(uniqueKeysWithValues: kvSq)
    }

    func getSavedAndEnabledSources() -> Results<StoredRunnerObject> {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == .source }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
    }
    
    func getSearchableSources() -> [StoredRunnerObject] {
        let disabledRunnerIDs: [String] = .init(rawValue: UserDefaults.standard.string(forKey: STTKeys.SourcesHiddenFromGlobalSearch) ?? "") ?? []
        return getSavedAndEnabledSources()
            .where { !$0.id.in(disabledRunnerIDs) }
            .freeze()
            .toArray()
    }

    func getLibraryPageProviders() -> [StoredRunnerObject] {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.isLibraryPageLinkProvider && $0.enabled && !$0.isDeleted }
            .map { $0.freeze() }
    }

    func getEnabledRunners(for environment: RunnerEnvironment) -> Results<StoredRunnerObject> {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == environment }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
    }
}
