//
//  Realm+LibraryCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift
import Foundation

extension RealmActor {
    func addCollection(withName name: String) async {
        try! await realm.asyncWrite {
            let collection = LibraryCollection()
            collection.name = name
            collection.order = realm.objects(LibraryCollection.self).count
            realm.add(collection)
        }
    }

    func reorderCollections(_ incoming: [LibraryCollection]) async {
        for collection in incoming {
            if let target = realm.objects(LibraryCollection.self).first(where: { $0.id == collection.id && collection.isDeleted == false }) {
                try! await realm.asyncWrite {
                    target.order = incoming.firstIndex(of: collection)!
                }
            }
        }
    }

    func renameCollection(_ collection: LibraryCollection, _ name: String) async {
        try! await realm.asyncWrite {
            guard let collection = collection.thaw() else {
                return
            }
            collection.name = name
        }
    }

    func deleteCollection(id: String) async {
        let collection = realm
            .objects(LibraryCollection.self)
            .first(where: { $0.isDeleted == false && $0.id == id })

        guard let collection else { return }

        try! await realm.asyncWrite {
            collection.isDeleted = true
            collection.filter?.isDeleted = true
        }
    }
}
