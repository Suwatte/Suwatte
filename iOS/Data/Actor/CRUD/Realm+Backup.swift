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

        backup.progressMarkers = progressMarkers.toArray()
        backup.library = libraryEntries.map(CodableLibraryEntry.from(entry:))
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

        var library: [LibraryEntry] = []
        if let entries = backup.library {
            let data = try DaisukeEngine.encode(value: entries)
            library = try DaisukeEngine.decode(data: data, to: [LibraryEntry].self)
        }
        try await realm.asyncWrite {
            if let markers = backup.markers {
                restoreOutdatedMarkers(markers, realm: realm)
            }

            if !library.isEmpty {
                let contents = library.compactMap { $0.content }
                realm.add(contents, update: .all)
                realm.add(library, update: .all)
            }

            if let collections = backup.collections {
                realm.add(collections, update: .all)
            }

            if let runnerLists = backup.lists {
                realm.add(runnerLists, update: .all)
            }

            if let markers = backup.progressMarkers {
                realm.add(markers, update: .all)
            }
        }
    }

    func restoreOutdatedMarkers(_ data: [OutdatedMarker], realm: Realm) {
        let data = Dictionary(grouping: data) { marker in
            ContentIdentifier(contentId: marker.chapter.contentId, sourceId: marker.chapter.sourceId)
        }

        func getReference(_ chapter: CodableChapter?, id: ContentIdentifier) -> ChapterReference? {
            guard let chapter else { return nil }
            let reference = ChapterReference()
            let content = StoredContent()
            content.id = id.id
            content.sourceId = id.sourceId
            content.contentId = id.contentId
            content.title = "~"
            reference.content = content
            reference.id = chapter.id
            reference.chapterId = chapter.chapterId
            reference.number = chapter.number
            reference.volume = chapter.volume
            return reference
        }

        for (id, markers) in data {
            guard !id.id.isEmpty else { continue }
            let readChapters = markers.map(\.chapter.chapterOrderKey)
            let maxRead = markers.max(by: \.chapter.chapterOrderKey)
            let reference = getReference(maxRead?.chapter, id: id)
            guard let reference, let maxRead else { continue }

            let marker = ProgressMarker()
            marker.id = id.id
            marker.readChapters.insert(objectsIn: readChapters)
            marker.currentChapter = reference
            marker.dateRead = maxRead.dateRead
            marker.lastPageRead = maxRead.lastPageRead
            marker.totalPageCount = maxRead.totalPageCount
            realm.add(marker, update: .modified)
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
