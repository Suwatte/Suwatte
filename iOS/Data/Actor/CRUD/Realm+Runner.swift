//
//  Realm+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import IceCream
import RealmSwift

extension RealmActor {
    func saveRunnerList(_ data: RunnerList, at url: URL) async {
        let obj = StoredRunnerList()
        obj.listName = data.listName
        obj.url = url.absoluteString
        await operation {
            realm.add(obj, update: .modified)
        }
    }

    func removeRunnerList(with url: String) async {
        let target = realm
            .objects(StoredRunnerList.self)
            .where { $0.url == url && !$0.isDeleted }
            .first
        guard let target else { return }

        await operation {
            target.isDeleted = true
        }
    }

    func deleteRunner(_ id: String) async {
        let runner = getRunner(id)
        guard let runner else { return }
        await operation {
            runner.isDeleted = true
        }
    }

    func getRunner(_ id: String) -> StoredRunnerObject? {
        getObject(of: StoredRunnerObject.self, with: id)
    }

    func getFrozenRunner(_ id: String) -> StoredRunnerObject? {
        getRunner(id)?.freeze()
    }

    func getRunnerName(for id: String) -> String? {
        getRunner(id)?.name
    }

    func saveRunner(_ runner: AnyRunner, listURL: URL? = nil, url: URL) async {
        let obj = getRunner(runner.id) ?? StoredRunnerObject()

        let info = runner.info
        await operation {
            obj.name = info.name

            if obj.id.isEmpty {
                obj.id = info.id
            }

            // Instance
            if let runner = runner as? AnyContentSource {
                let allowsInstances = runner.config?.allowsMultipleInstances ?? false
                if !obj.isInstantiable, allowsInstances, obj.parentRunnerID == nil {
                    obj.isInstantiable = true
                }
            }

            obj.version = info.version
            obj.environment = runner.environment
            obj.isBrowsePageLinkProvider = runner.intents.browsePageLinkProvider
            obj.isLibraryPageLinkProvider = runner.intents.libraryPageLinkProvider
            obj.isDeleted = false

            if let listURL {
                obj.listURL = listURL.absoluteString
            }

            if obj.executable == nil || url.exists {
                obj.executable = CreamAsset.create(object: obj, folder: StoredRunnerObject.RUNNER_KEY, url: url)
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
        getRunner(id)?
            .executable?
            .filePath
    }

    func getAllRunnerNames() -> [String: String] {
        let kvSq = realm
            .objects(StoredRunnerObject.self)
            .map { ($0.id, $0.name) }

        return Dictionary(uniqueKeysWithValues: kvSq)
    }

    private func getSavedAndEnabledSources() -> Results<StoredRunnerObject> {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == .source }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
    }

    func getSavedAndEnabledSources() -> [StoredRunnerObject] {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == .source }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
            .freeze()
            .toArray()
    }

    func getSavedAndEnabledRunners() -> [StoredRunnerObject] {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
            .freeze()
            .toArray()
    }

    func getSearchableSources() -> [StoredRunnerObject] {
        let disabledRunnerIDs: [String] = Array(Preferences.standard.disabledGlobalSearchSources)
        return getSavedAndEnabledSources()
            .where { !$0.id.in(disabledRunnerIDs) }
            .freeze()
            .toArray()
    }

    func getLibraryPageProviders() -> [StoredRunnerObject] {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.isLibraryPageLinkProvider && $0.enabled && !$0.isDeleted }
            .freeze()
            .toArray()
    }

    func getEnabledRunners(for environment: RunnerEnvironment) -> [StoredRunnerObject] {
        realm
            .objects(StoredRunnerObject.self)
            .where { $0.enabled == true && $0.isDeleted == false && $0.environment == environment }
            .sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
            .freeze()
            .toArray()
    }

    func getRunnerLists() -> [StoredRunnerList] {
        realm
            .objects(StoredRunnerList.self)
            .where { !$0.isDeleted }
            .sorted(by: \.listName, ascending: true)
            .freeze()
            .toArray()
    }
}

extension RealmActor {
    func createNewInstance(of id: String) async {
        let target = getRunner(id)

        guard let target else { return }
        let count = realm
            .objects(StoredRunnerObject.self)
            .where { $0.parentRunnerID == target.id && $0.isDeleted == false }
            .count + 1

        let object = StoredRunnerObject(value: target)
        object.parentRunnerID = target.id
        object.id = "\(target.id)-\(UUID().uuidString)"
        object.name = "\(target.name) \(count)"
        object.isInstantiable = false

        await operation {
            realm.add(object, update: .modified)
        }
    }
}
