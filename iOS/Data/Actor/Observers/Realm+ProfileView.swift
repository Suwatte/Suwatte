//
//  Realm+ProfileView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import Foundation
import RealmSwift

extension RealmActor {
    typealias Callback<T> = (T) -> Void
    func observeLibraryState(for id: String, _ callback: @escaping Callback<Bool>) async -> NotificationToken {
        let ids = getLinkedContent(for: id).map(\.id).appending(id)
        let collection = realm
            .objects(LibraryEntry.self)
            .where { $0.id.in(ids) && !$0.isDeleted }

        func didUpdate(_ results: Results<LibraryEntry>) {
            let inLibrary = !results.isEmpty
            Task { @MainActor in
                callback(inLibrary)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }

    func observeReadLaterState(for id: String, _ callback: @escaping Callback<Bool>) async -> NotificationToken {
        let collection = realm
            .objects(ReadLater.self)
            .where { $0.id == id }
            .where { !$0.isDeleted }

        func didUpdate(_ results: Results<ReadLater>) {
            let savedForLater = !results.isEmpty
            Task { @MainActor in
                callback(savedForLater)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }

    func observeReadChapters(for id: String, _ callback: @escaping Callback<[String: [String: ThreadSafeProgressMarker]]>) async -> NotificationToken {
        let ids = getLinkedContent(for: id)
            .map(\.id)
            .appending(id)

        let collection = realm
            .objects(ProgressMarker.self)
            .where { $0.chapter.contentId.in(ids) && !$0.isDeleted }

        func didUpdate(_ results: Results<ProgressMarker>) {
            let readChaptersByContent = createDictionaryFromResults(results)

            Task { @MainActor in
                callback(readChaptersByContent)
            }

            func createDictionaryFromResults(_ results: Results<ProgressMarker>) -> [String: [String: ThreadSafeProgressMarker]] {
                var readChaptersByContent = [String: [String: ThreadSafeProgressMarker]]()
                for result in results.toArray() {
                    readChaptersByContent[result.chapter!.content!.id, default: [:]][result.id] = result.toThreadSafe()
                }
                return readChaptersByContent
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }

    func observeDownloadStatus(for id: String, _ callback: @escaping Callback<[String: DownloadStatus]>) async -> NotificationToken {
        let contents = getLinkedContent(for: id)
            .map(\.id)
            .appending(id)

        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.content != nil }
            .where { $0.content.id.in(contents) }

        func didUpdate(_ results: Results<SourceDownload>) {
            let dictionary = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0.status) })
            Task { @MainActor in
                callback(dictionary)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }
}

extension RealmActor {
    func observeChapterBookmarks(_ callback: @escaping Callback<Set<String>>) async -> NotificationToken {
        let collection = realm
            .objects(ChapterBookmark.self)
            .where { !$0.isDeleted }
            .where { $0.chapter != nil }

        func didUpdate(_ results: Results<ChapterBookmark>) {
            let data = Set(results.map(\.id))

            Task { @MainActor in
                callback(data)
            }
        }

        return await observeCollection(collection: collection, didUpdate)
    }
}
