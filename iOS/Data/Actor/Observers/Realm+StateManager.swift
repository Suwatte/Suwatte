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
}
