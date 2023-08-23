//
//  Realm+ReadLaterView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeReadLater(query: String, ascending: Bool, sort: LibraryView.ReadLaterView.ContentSort ,_ callback: @escaping Callback<[ReadLater]>)  async -> NotificationToken {
        var collection = realm
            .objects(ReadLater.self)
            .where { $0.content != nil && $0.isDeleted == false }
            .sorted(byKeyPath: sort.KeyPath, ascending: ascending)

        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            collection = collection
                .filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@",
                        query, query, query)
        }
        
        
        func didUpdate(_ results: Results<ReadLater>) {
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
