//
//  Realm+HighlightGrid.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import RealmSwift


extension RealmActor {
    
    
    func observeLibraryIDs(_ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        
        let collection = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }
        
        func didUpdate(_ result: Results<LibraryEntry>) {
            let ids = Set(result.map(\.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate(_:))
    }
    
    
    func observeReadLaterIDs(_ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        
        let collection = realm
            .objects(ReadLater.self)
            .where { $0.content != nil && !$0.isDeleted }
        
        func didUpdate(_ result: Results<ReadLater>) {
            let ids = Set(result.map(\.id) as [String])
            Task { @MainActor in
                callback(ids)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate(_:))
    }
}
