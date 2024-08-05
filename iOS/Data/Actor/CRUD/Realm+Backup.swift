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
        let storedContents = realm
            .objects(StoredContent.self)
            .where { !$0.isDeleted }
            .freeze()

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
            .where { $0.chapter != nil && $0.chapter.content != nil && !$0.isDeleted }
            .freeze()

        let contentLinks = realm
            .objects(ContentLink.self)
            .where { $0.entry != nil && $0.content != nil && !$0.isDeleted }
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

        backup.storedContents = storedContents.toArray()
        backup.progressMarkers = progressMarkers.toArray()
        backup.library = libraryEntries.toArray()
        backup.collections = collections.toArray()
        backup.lists = lists.toArray()
        backup.runners = runners.toArray()
        backup.contentLinks = contentLinks.map(CodableContentLink.from(contentLink: ))
        return backup
    }
}

// MARK: - Restore

extension RealmActor {
    func restoreBackup(backup: Backup) async throws {
        try await resetDB()

        if backup.schemaVersion > 15 {
            if let entries = backup.library {
                try entries.forEach { try $0.fillContent(data: backup.storedContents ) }
            }

            if let entries = backup.progressMarkers {
                try entries.forEach { try $0.chapter!.fromBackup(data: backup.storedContents) }
            }
        }

        let contentLinks: [ContentLink] = try backup.contentLinks?.compactMap { try $0.restore(storedContent: backup.storedContents, library: backup.library) } ?? []

        try await realm.asyncWrite {
            if let markers = backup.markers {
                restoreOutdatedMarkers(markers, realm: realm)
            }

            if let storedContents = backup.storedContents {
                realm.add(storedContents, update: .all)
            }

            if let library = backup.library {
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

            if !contentLinks.isEmpty {
                realm.add(contentLinks, update: .all)
            }
        }
    }

    func restoreOutdatedMarkers(_ data: [OutdatedMarker], realm: Realm) {
        func getReference(_ chapter: CodableChapter?, id: ContentIdentifier) -> ChapterReference? {
            guard let chapter else { return nil }

            let content = StoredContent()
            content.id = id.id
            content.sourceId = id.sourceId
            content.contentId = id.contentId
            content.title = "~"

            let reference = ChapterReference()
            reference.content = content
            reference.id = chapter.id
            reference.chapterId = chapter.chapterId
            reference.number = chapter.number
            reference.volume = chapter.volume

            return reference
        }

        for marker in data {
            guard !marker.id.isEmpty else {
                continue
            }

            let id = ContentIdentifier(contentId: marker.chapter.contentId, sourceId: marker.chapter.sourceId)
            let reference = getReference(marker.chapter, id: id)
            guard let reference else { continue }

            let marker = ProgressMarker()
            marker.id = id.id
            marker.chapter = reference
            marker.dateRead = marker.dateRead
            marker.lastPageRead = marker.lastPageRead
            marker.totalPageCount = marker.totalPageCount
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

            realm.objects(ArchivedContent.self).setValue(true, forKey: "isDeleted") // 1. No relation
            realm.objects(CustomThumbnail.self).setValue(true, forKey: "isDeleted") // 7. Relation: CreamAsset
            realm.objects(InteractorStoreObject.self).setValue(true, forKey: "isDeleted") // 8. No relation
            realm.objects(LibraryCollectionFilter.self).setValue(true, forKey: "isDeleted") // 10. No relation
            realm.objects(LibraryCollection.self).setValue(true, forKey: "isDeleted") // 9. Relation: LibraryCollectionFilter
            realm.objects(StoredOPDSServer.self).setValue(true, forKey: "isDeleted") // 19. No relation
            realm.objects(StoredRunnerList.self).setValue(true, forKey: "isDeleted") // 21. No relation
            realm.objects(StoredRunnerObject.self).setValue(true, forKey: "isDeleted") // 22. Relation: CreamAsset
            realm.objects(StoredTag.self).setValue(true, forKey: "isDeleted") // 23. No relation
            realm.objects(StoredProperty.self).setValue(true, forKey: "isDeleted") // 20. Relation: StoredTag
            realm.objects(StreamableOPDSContent.self).setValue(true, forKey: "isDeleted") // 24. Relation: StoredOPDSServer
            realm.objects(TrackerLink.self).setValue(true, forKey: "isDeleted") // 25. No relation
            realm.objects(UpdatedSearchHistory.self).setValue(true, forKey: "isDeleted") // 27. No relation
            realm.objects(UserReadingStatistic.self).setValue(true, forKey: "isDeleted") // 28. No relation



            realm.objects(LibraryEntry.self).setValue(true, forKey: "isDeleted") // 11. Relation: StoredContent
            realm.objects(ContentLink.self).setValue(true, forKey: "isDeleted") // 4. Relation: LibraryEntry, StoredContent

            realm.objects(ReadLater.self).setValue(true, forKey: "isDeleted") // 13. Relation: StoredContent


            realm.objects(ChapterReference.self).setValue(true, forKey: "isDeleted") // 3. Relation: StoredContent, StreamableOPDSContent, ArchivedContent
            realm.objects(ChapterBookmark.self).setValue(true, forKey: "isDeleted") // 2. Relation: ChapterReference
            realm.objects(UpdatedBookmark.self).setValue(true, forKey: "isDeleted") // 26. Relation: ChapterReference, CreamAsset
            realm.objects(ProgressMarker.self).setValue(true, forKey: "isDeleted") // 12. Relation: ChapterReference



            // Relation: 14. StoredChapter, StoredContent
            let downloadedChapters = realm
                .objects(SourceDownload.self)
                .where { $0.chapter != nil && $0.status != .cancelled }
                .compactMap(\.chapter?.id) as [String]

            // Relation: 15. StoredContent
            let downloadedTitles = realm
                .objects(SourceDownloadIndex.self)
                .where { $0.count > 0 && $0.content != nil }
                .compactMap(\.content?.id) as [String]

            // 16. Relation: No Relation
            let chapters = realm
                .objects(StoredChapter.self)
                .where { !$0.id.in(downloadedChapters) }

            realm.delete(chapters)

            // Relation: 18. StoredProperty
            realm
                .objects(StoredContent.self)
                .where { !$0.id.in(downloadedTitles) }
                .setValue(true, forKey: "isDeleted")

            realm.delete(realm.objects(StoredChapterData.self)) // 17. Relation: StoredChapter
        }
    }
}
