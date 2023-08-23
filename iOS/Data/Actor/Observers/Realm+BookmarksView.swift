//
//  Realm+BookmarksView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeBookmarks(for id: String, _ callback: @escaping Callback<[UpdatedBookmark]>)  async -> NotificationToken {
        let collection = realm
            .objects(UpdatedBookmark.self)
            .where { !$0.isDeleted }
            .where { $0.chapter != nil }
            .where { $0.chapter.content.id == id ||
                $0.chapter.archive.id == id || $0.chapter.opds.id == id }
            .where { $0.asset != nil }
            .sorted(by: \.dateAdded, ascending: false)
        
        func didUpdate(_ results: Results<UpdatedBookmark>) {
            let list = results
                .freeze()
                .toArray()
            
            Task { @MainActor in
                callback(list)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate)
    }
}
