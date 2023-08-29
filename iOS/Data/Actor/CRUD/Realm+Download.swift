//
//  Realm+Download.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getActiveDownload(_ id: String) -> SourceDownload? {
        return realm
            .objects(SourceDownload.self)
            .where { $0.content != nil && $0.chapter != nil }
            .where { $0.id == id && $0.status == .active }
            .first?
            .freeze()
    }

    func updateDownloadIndex(for ids: [String]) async {
        await withTaskGroup(of: Void.self, body: { _ in
            for id in ids {
                let collection = realm
                    .objects(SourceDownload.self)
                    .where { $0.content.id == id }
                    .where { $0.status == .completed }
                    .sorted(by: \.dateAdded, ascending: true) // First Points to earliest, last points to latest

                let count = collection.count

                var target = realm
                    .objects(SourceDownloadIndex.self)
                    .where { $0.id == id }
                    .first

                // Target not found, new index, create
                if target == nil {
                    let idx = SourceDownloadIndex()
                    idx.id = id
                    idx.content = getStoredContent(id)
                    target = idx
                }

                guard let target else { return }

                await operation {
                    if let earliest = collection.first {
                        target.dateFirstAdded = earliest.dateAdded
                    }

                    if let latest = collection.last {
                        target.dateLastAdded = latest.dateAdded
                    }

                    target.count = count
                    realm.add(target, update: .modified)
                }
            }
        })
    }
}
