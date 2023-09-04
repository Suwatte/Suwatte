//
//  Realm+Backup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

// MARK: - Create

extension RealmActor {
    func createBackup() -> Backup {
        let libraryEntries = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }
            .freeze()

        let collections = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .freeze()

        let progressMarkers = realm
            .objects(ProgressMarker.self)
            .where { $0.currentChapter != nil && $0.currentChapter.content != nil && !$0.isDeleted }
            .freeze()

        let lists = realm
            .objects(StoredRunnerList.self)
            .where { !$0.isDeleted }
            .freeze()

        let runners = realm
            .objects(StoredRunnerObject.self)
            .where { !$0.isDeleted }
            .freeze()

        var backup = Backup()

        backup.markers = progressMarkers.toArray()
        backup.library = libraryEntries.toArray()
        backup.collections = collections.toArray()
        backup.lists = lists.toArray()
        backup.runners = runners.toArray()

        return backup
    }
}

// MARK: - Restore

extension RealmActor {
    func restoreBackup(backup: Backup) async throws {
        try await resetDB()

        try await realm.asyncWrite {
            if let libraryEntries = backup.library {
                let contents = libraryEntries.compactMap { $0.content }
                realm.add(contents, update: .all)
                realm.add(libraryEntries, update: .all)
            }

            if let collections = backup.collections {
                realm.add(collections, update: .all)
            }

            if let runnerLists = backup.lists {
                realm.add(runnerLists, update: .all)
            }

            if let markers = backup.markers {
                realm.add(markers, update: .all)
            }
        }
    }
}

extension RealmActor {
    func resetDB() async throws {
        let noActiveDownloads = realm
            .objects(SourceDownload.self)
            .where { $0.status == .active || $0.status == .queued || $0.status == .idle }
            .isEmpty

        guard noActiveDownloads else {
            throw DSK.Errors.NamedError(name: "Active Downloads",
                                        message: "You currently have downloads that are either active or queued.")
        }

        try await realm.asyncWrite {
            realm.objects(LibraryEntry.self).setValue(true, forKey: "isDeleted")
            realm.objects(LibraryCollection.self).setValue(true, forKey: "isDeleted")
            realm.objects(UpdatedBookmark.self).setValue(true, forKey: "isDeleted")
            realm.objects(ReadLater.self).setValue(true, forKey: "isDeleted")
            realm.objects(ProgressMarker.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredRunnerList.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredRunnerObject.self).setValue(true, forKey: "isDeleted")
            realm.objects(CustomThumbnail.self).setValue(true, forKey: "isDeleted")
            realm.objects(ChapterReference.self).setValue(true, forKey: "isDeleted")
            realm.objects(StreamableOPDSContent.self).setValue(true, forKey: "isDeleted")
            realm.objects(InteractorStoreObject.self).setValue(true, forKey: "isDeleted")
            realm.objects(TrackerLink.self).setValue(true, forKey: "isDeleted")
            realm.objects(ContentLink.self).setValue(true, forKey: "isDeleted")
            realm.objects(ArchivedContent.self).setValue(true, forKey: "isDeleted")
            realm.objects(LibraryCollectionFilter.self).setValue(true, forKey: "isDeleted")
            realm.objects(UpdatedSearchHistory.self).setValue(true, forKey: "isDeleted")
            realm.objects(StoredOPDSServer.self).setValue(true, forKey: "isDeleted")
            realm.objects(ChapterBookmark.self).setValue(true, forKey: "isDeleted")
            realm.delete(realm.objects(StoredChapterData.self))

            let downloadedTitles = realm
                .objects(SourceDownloadIndex.self)
                .where { $0.count > 0 && $0.content != nil }
                .compactMap(\.content?.id) as [String]

            let downloadedChapters = realm
                .objects(SourceDownload.self)
                .where { $0.chapter != nil && $0.status != .cancelled }
                .compactMap(\.chapter?.id) as [String]

            realm
                .objects(StoredContent.self)
                .where { !$0.id.in(downloadedTitles) }
                .setValue(true, forKey: "isDeleted")

            let chapters = realm
                .objects(StoredChapter.self)
                .where { !$0.id.in(downloadedChapters) }

            realm.delete(chapters)
        }
    }
}
