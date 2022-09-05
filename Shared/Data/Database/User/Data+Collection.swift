//
//  Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

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

final class LibraryCollectionFilter: EmbeddedObject {
    @Persisted var adultContent: ContentSelectionType = .both
    @Persisted var readingFlags: List<LibraryFlag>
    @Persisted var textContains: List<String>
    @Persisted var statuses: List<ContentStatus>
    @Persisted var sources: List<String>
    @Persisted var tagContains: List<String>
    @Persisted var contentType: List<ExternalContentType>
}

final class LibraryCollection: Object {
    @Persisted(primaryKey: true) var _id: String = UUID().uuidString
    @Persisted var name: String
    @Persisted var order: Int
    @Persisted var filter: LibraryCollectionFilter?
}

extension LibraryCollection: Identifiable {
    var id: String {
        return _id
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
            if let target = realm.objects(LibraryCollection.self).first(where: { $0.id == collection.id }) {
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
}
