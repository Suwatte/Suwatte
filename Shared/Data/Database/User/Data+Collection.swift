//
//  Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift
import IceCream

enum ContentSelectionType: Int, PersistableEnum, CaseIterable, Identifiable, Codable {
    case none, only, both

    var description: String {
        switch self {
        case .none:
            return "None"
        case .only:
            return "Only"
        case .both:
            return "Both"
        }
    }

    var id: Int {
        hashValue
    }
}

enum ExternalContentType: Int, PersistableEnum, CaseIterable, Identifiable, Codable {
    case novel, manga, manhua, manhwa, comic, unknown

    var id: Int {
        hashValue
    }

    var description: String {
        switch self {
        case .novel:
            return "Novel"
        case .manga:
            return "Manga"
        case .manhua:
            return "Manhua"
        case .manhwa:
            return "Manhwa"
        case .comic:
            return "Comic"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: Manager Functions

extension DataManager {
    func addCollection(withName name: String) {
        let realm = try! Realm()

        try! realm.safeWrite {
            let collection = LibraryCollection()
            collection.name = name
            collection.order = realm.objects(LibraryCollection.self).count
            realm.add(collection)
        }
    }

    func reorderCollections(_ incoming: [LibraryCollection]) {
        let realm = try! Realm()

        for collection in incoming {
            if let target = realm.objects(LibraryCollection.self).first(where: { $0.id == collection.id && collection.isDeleted == false }) {
                try! realm.safeWrite {
                    target.order = incoming.firstIndex(of: collection)!
                }
            }
        }
    }

    func renameCollection(_ collection: LibraryCollection, _ name: String) {
        let realm = try! Realm()

        try! realm.safeWrite {
            guard let collection = collection.thaw() else {
                return
            }
            collection.name = name
        }
    }
    
    func deleteCollection(id: String) {
        let realm = try! Realm()
        
        let collection = realm
            .objects(LibraryCollection.self)
            .first(where: { $0.isDeleted == false && $0.id == id })
        
        guard let collection else { return }
        
        try! realm.safeWrite {
            collection.isDeleted = true
            collection.filter?.isDeleted = true
        }
    }
}
