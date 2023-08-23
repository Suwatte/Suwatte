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
                case let .error(error):
                    Logger.shared.error(error)
                case let .initial(initialDataSet):
                    let frozen = initialDataSet.freeze()
                    onUpdate(frozen)
                case let .update(updatedDataSet, _, _, _):
                    let frozen = updatedDataSet.freeze()
                    onUpdate(frozen)
                }
            }
    }
}
