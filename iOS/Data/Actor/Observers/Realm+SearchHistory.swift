//
//  Realm+SearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-04.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeSearchHistory(id: String? = nil, _ callback: @escaping Callback<[UpdatedSearchHistory]>) async -> NotificationToken {
        var collection = realm
            .objects(UpdatedSearchHistory.self)
            .where { !$0.isDeleted }
            .sorted(by: \.date, ascending: false)

        if let id {
            collection = collection
                .where { $0.sourceId == id }
        }

        func didUpdate(_ results: Results<UpdatedSearchHistory>) {
            let data = results
                .freeze()
                .toArray()
            Task { @MainActor in
                callback(data)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }
}
