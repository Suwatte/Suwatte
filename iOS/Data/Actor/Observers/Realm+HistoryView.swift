//
//  Realm+HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeHistory(_ callback: @escaping Callback<[ProgressMarker]>) async -> NotificationToken {
        let threeMonths = Calendar
            .current
            .date(byAdding: .month,
                  value: -3,
                  to: .now)!

        let collection = realm
            .objects(ProgressMarker.self)
            .where { !$0.isDeleted }
            .where { $0.chapter != nil }
            .where { $0.dateRead != nil }
            .where { $0.dateRead >= threeMonths }
            .sorted(by: \.dateRead, ascending: false)
            .distinct(by: ["chapter.contentId"])

        func didUpdate(_ results: Results<ProgressMarker>) {
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
