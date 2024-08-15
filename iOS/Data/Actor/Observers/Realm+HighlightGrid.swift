//
//  Realm+HighlightGrid.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeLinkedIDs(sourceID: String? = nil, _ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        var collection = realm
            .objects(ContentLink.self)
            .where { $0.content != nil && $0.entry != nil && !$0.isDeleted }

        if let sourceID {
            collection = collection
                .where { $0.content.sourceId == sourceID }
        }

        func didUpdate(_ result: Results<ContentLink>) {
            let ids = Set(result.map(\.content!.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }

        return await observeCollection(collection: collection, didUpdate(_:))
    }

    func observeLibraryIDs(sourceID: String? = nil, _ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        var collection = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }

        if let sourceID {
            collection = collection
                .where { $0.content.sourceId == sourceID }
        }

        func didUpdate(_ result: Results<LibraryEntry>) {
            let ids = Set(result.map(\.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }

        return await observeCollection(collection: collection, didUpdate(_:))
    }

    func observeReadLaterIDs(sourceID: String? = nil, _ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        var collection = realm
            .objects(ReadLater.self)
            .where { $0.content != nil && !$0.isDeleted }

        if let sourceID {
            collection = collection
                .where { $0.content.sourceId == sourceID }
        }

        func didUpdate(_ result: Results<ReadLater>) {
            let ids = Set(result.map(\.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }

        return await observeCollection(collection: collection, didUpdate(_:))
    }
}
