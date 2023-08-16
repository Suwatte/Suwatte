//
//  Realm+BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import Foundation
import RealmSwift

extension RealmActor {
    
    func observeInstalledRunners(onlyEnabled: Bool = true, _ callback: @escaping Callback<[StoredRunnerObject]>) async -> NotificationToken {
        var collection = realm
            .objects(StoredRunnerObject.self)
            .where { !$0.isDeleted }
        
        if onlyEnabled {
            collection = collection
                .where { $0.enabled }
        }
        collection = collection
            .sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true), SortDescriptor(keyPath: "name", ascending: true)])

        func didUpdate(_ results: Results<StoredRunnerObject>) {
            let list = results
                .freeze()
                .toArray()
            
            callback(list)
        }
        return await observeCollection(collection: collection, didUpdate)
    }
}
