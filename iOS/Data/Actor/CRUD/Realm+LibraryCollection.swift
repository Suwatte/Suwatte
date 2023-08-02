//
//  Realm+LibraryCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift
import Foundation

extension RealmActor {
    
    func getLibraryCollection( for id: String) -> LibraryCollection? {
        realm
            .objects(LibraryCollection.self)
            .where { $0.id == id && !$0.isDeleted }
            .first
    }
    func addCollection(withName name: String) async {
        try! await realm.asyncWrite {
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
        
        try! await realm.asyncWrite {
            for collection in collections {
                collection.order = incoming.firstIndex(of: collection.id) ?? 999
                
            }
        }
    }

    func renameCollection(_ collection: String, _ name: String) async {
        let collection = getLibraryCollection(for: collection)
        guard let collection else { return }
        try! await realm.asyncWrite {
            collection.name = name
        }
    }

    func deleteCollection(id: String) async {
        let collection = realm
            .objects(LibraryCollection.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        guard let collection else { return }

        try! await realm.asyncWrite {
            collection.isDeleted = true
            collection.filter?.isDeleted = true
        }
    }
}