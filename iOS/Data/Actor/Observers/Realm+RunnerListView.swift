//
//  Realm+RunnerListView.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import Foundation
import RealmSwift

extension RealmActor {
    
    func observeSavedRunnerLists(_ callback: @escaping Callback<[StoredRunnerList]>) async -> NotificationToken {
        let collection = realm
            .objects(StoredRunnerList.self)
            .where { !$0.isDeleted }
            .sorted(by: \.listName, ascending: true)
        
        func didUpdate(_ results: Results<StoredRunnerList>) {
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
