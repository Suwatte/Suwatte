//
//  Realm+StateManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import RealmSwift

extension RealmActor {
    func observeLibraryCollection(_ callback: @escaping Callback<[LibraryCollection]>) async -> NotificationToken {
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
