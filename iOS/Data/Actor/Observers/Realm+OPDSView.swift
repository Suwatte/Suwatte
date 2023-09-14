//
//  Realm+OPDSView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-04.
//

import RealmSwift

extension RealmActor {
    func observeOPDSServers(_ callback: @escaping Callback<[StoredOPDSServer]>) async -> NotificationToken {
        let collection = realm
            .objects(StoredOPDSServer.self)
            .where { !$0.isDeleted }
            .sorted(by: \.alias, ascending: true)

        func didUpdate(_ results: Results<StoredOPDSServer>) {
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
