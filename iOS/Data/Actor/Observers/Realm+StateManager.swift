//
//  Realm+StateManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import RealmSwift

extension RealmActor {
    func observeCustomThumbnails(_ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        let collection = realm
            .objects(CustomThumbnail.self)
            .where { !$0.isDeleted }
            .where { $0.file != nil }

        func didUpdate(_ result: Results<CustomThumbnail>) {
            let ids = Set(result.map(\.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }

        return await observeCollection(collection: collection, didUpdate(_:))
    }
    
    func observeLibraryCollection(_ callback: @escaping Callback<Array<LibraryCollection>>) async -> NotificationToken {
        let collection = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .sorted(by: \.order, ascending: true)

        func didUpdate(_ result: Results<LibraryCollection>) {
            let data = result
                .freeze()
                .toArray()
            Task { @MainActor in
                callback(data)
            }
        }

        return await observeCollection(collection: collection, didUpdate(_:))
    }
    
}
