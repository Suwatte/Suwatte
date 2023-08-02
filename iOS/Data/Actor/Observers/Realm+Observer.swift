//
//  Realm+Observer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import Foundation
import RealmSwift



extension RealmActor {
    func observeCollection<T: Object>(collection: Results<T>, _ onUpdate: @escaping (Results<T>) -> Void) async -> NotificationToken {
        await collection
            .observe(on: self) { _, changeSet in
                switch changeSet {
                case .error(let error):
                    Logger.shared.error(error)
                case .initial(let initialDataSet):
                    let frozen = initialDataSet.freeze()
                    onUpdate(frozen)
                case .update(let updatedDataSet, _, _, _):
                    let frozen = updatedDataSet.freeze()
                    onUpdate(frozen)
                }
            }
    }
}
