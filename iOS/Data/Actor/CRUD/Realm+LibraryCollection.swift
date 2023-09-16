//
//  Realm+LibraryCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getLibraryCollection(for id: String) -> LibraryCollection? {
        getObject(of: LibraryCollection.self, with: id)
    }

    func addCollection(withName name: String) async {
        await operation {
            let collection = LibraryCollection()
            collection.name = name
            collection.order = realm.objects(LibraryCollection.self).count
            realm.add(collection)
        }
    }

    func reorderCollections(_ incoming: [String]) async {
        let collections = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }

        await operation {
            for collection in collections {
                collection.order = incoming.firstIndex(of: collection.id) ?? 999
            }
        }
    }

    func renameCollection(_ collection: String, _ name: String) async {
        let collection = getLibraryCollection(for: collection)
        guard let collection else { return }
        await operation {
            collection.name = name
        }
    }

    func deleteCollection(id: String) async {
        let collection = realm
            .objects(LibraryCollection.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        guard let collection else { return }

        await operation {
            collection.isDeleted = true
            collection.filter?.isDeleted = true
        }
    }
}

extension RealmActor {
    func toggleCollectionFilters(id: String, value: Bool) async {
        let collection = getLibraryCollection(for: id)
        guard let collection else { return }

        await operation {
            if value {
                if collection.filter == nil {
                    collection.filter = LibraryCollectionFilter()
                }
            } else {
                if let filter = collection.filter {
                    filter.isDeleted = true
                }
                collection.filter = nil
            }
        }
    }

    func saveCollectionFilters(for id: String, filter: LibraryCollectionFilter) async {
        let collection = getLibraryCollection(for: id)
        guard let collection else { return }
        await operation {
            realm.add(filter, update: .modified)
            collection.filter = filter
        }
    }
}
