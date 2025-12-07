//
//  Realm+UpdateFeed.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation
import RealmSwift

struct UpdateFeedGroup: Hashable {
    var header: String
    var content: [LibraryEntry]
}

extension RealmActor {
    func observeUpdateFeed(_ callback: @escaping Callback<[UpdateFeedGroup]>) async -> NotificationToken {
        // Updates going 2 months back
        let date = Calendar.current.date(byAdding: .month, value: -2, to: .now)!
        let collection = realm
            .objects(LibraryEntry.self)
            .where { !$0.isDeleted }
            .where { $0.content != nil }
            .where { $0.updateCount > 0 }
            .where { $0.lastUpdated >= date }
            .sorted(by: \.lastUpdated, ascending: false)

        func generate(entries: [LibraryEntry]) -> [UpdateFeedGroup] {
            let grouped = Dictionary(grouping: entries,
                                     by: { $0.lastUpdated.timeAgoGrouped() })
            let sortedKeys = grouped
                .keys
                .sorted(by: { grouped[$0]![0].lastUpdated > grouped[$1]![0].lastUpdated })
            var data = [UpdateFeedGroup]()
            for sortedKey in sortedKeys {
                data.append(.init(header: sortedKey, content: grouped[sortedKey] ?? []))
            }

            return data
        }

        func didUpdate(_ results: Results<LibraryEntry>) {
            let data = results
                .freeze()
                .toArray()
            let grouped = generate(entries: data)
            Task { @MainActor in
                callback(grouped)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }
}
