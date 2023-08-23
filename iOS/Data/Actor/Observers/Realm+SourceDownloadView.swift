//
//  Realm+SourceDownloadView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation
import RealmSwift

extension RealmActor {
    func observeDownloads(query: String, ascending: Bool, sort: SourceDownloadView.SortOption, _ callback: @escaping Callback<[SourceDownloadIndex]>) async -> NotificationToken {
        var collection = realm
            .objects(SourceDownloadIndex.self)
            .where { $0.content != nil && $0.count > 0 }

        switch sort {
        case .title:
            collection = collection
                .sorted(by: \.content?.title, ascending: ascending)
        case .downloadCount:
            collection = collection
                .sorted(by: \.count, ascending: ascending)
        case .dateAdded:
            collection = collection
                .sorted(by: \.dateLastAdded, ascending: ascending)
        }
        if !query.isEmpty {
            collection = collection
                .filter("ANY content.additionalTitles CONTAINS[cd] %@ OR content.title CONTAINS[cd] %@ OR content.summary CONTAINS[cd] %@", query, query, query)
        }

        func didUpdate(_ results: Results<SourceDownloadIndex>) {
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

extension RealmActor {
    func observeDownloadsQueue(_ callback: @escaping Callback<[[SourceDownload]]>) async -> NotificationToken {
        let visisble: [DownloadStatus] = [.queued, .paused, .failing]
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.content != nil && $0.chapter != nil }
            .where { $0.status.in(visisble) }
            .sectioned(by: \.content?.id, sortDescriptors: [.init(keyPath: "content.id"), .init(keyPath: "dateAdded", ascending: true)])

        func didUpdate(_: SectionedResults<String?, SourceDownload>) {
            let build = collection.map { Array($0.freeze()) }
            Task { @MainActor in
                callback(build)
            }
        }

        let token = collection.observe { changeSet in
            switch changeSet {
            case let .initial(results):
                didUpdate(results)
            case .update(let results, deletions: _, insertions: _, modifications: _, sectionsToInsert: _, sectionsToDelete: _):
                didUpdate(results)
            }
        }

        return token
    }
}
