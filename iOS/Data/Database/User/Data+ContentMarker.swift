//
//  Data+ContentMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-27.
//

import Foundation
import RealmSwift

extension DataManager {
    func getContentMarker(for id: String) -> ProgressMarker? {
        let realm = try! Realm()

        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        return target
    }

    func didCompleteChapter(for id: String, chapter: ThreadSafeChapter) {
        let realm = try! Realm()

        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        var reference: ChapterReference?

        switch chapter.sourceId {
        case STTHelpers.LOCAL_CONTENT_ID:
            let content = realm
                .objects(ArchivedContent.self)
                .where({ $0.id == chapter.contentId  && !$0.isDeleted  })
                .first
            reference = chapter.toStored().generateReference()
            reference?.archive = content
        case STTHelpers.OPDS_CONTENT_ID:
            let content = realm
                .objects(StreamableOPDSContent.self)
                .where { $0.id == chapter.id  && !$0.isDeleted  }
                .first
            reference = chapter.toStored().generateReference()
            reference?.opds = content
        default:
            reference = chapter.toStored().generateReference()
            reference?.content = DataManager.shared.getStoredContent(id)
        }

        // Ensure Chapter Reference has been generated, Save Reference
        let hasValidReference = reference?.content != nil || reference?.archive != nil || reference?.opds != nil
        guard let reference, hasValidReference else { return }

        try! realm.safeWrite {
            realm.add(reference, update: .modified)
        }

        // Has Marker, Update
        if let target {
            let prevMarkerID = target.currentChapter?.id
            try! realm.safeWrite {
                target.dateRead = .now
                target.lastPageRead = nil
                target.totalPageCount = nil
                target.lastPageOffset = nil
                target.readChapters.insert(chapter.number)
                target.currentChapter = reference
            }

            if let prevMarkerID, prevMarkerID != chapter.id {
                validateChapterReference(id: prevMarkerID, realm)
            }
            DataManager.shared.decrementUnreadCount(for: id, realm)

            return
        }

        // Marker DNE, Create

        let marker = ProgressMarker()
        marker.id = id
        marker.readChapters.insert(chapter.number)
        marker.currentChapter = reference

        try! realm.safeWrite {
            realm.add(marker, update: .modified)
        }
        DataManager.shared.decrementUnreadCount(for: id, realm)
    }

    func updateContentProgress(for id: String, chapter: ThreadSafeChapter, lastPageRead: Int, totalPageCount: Int, lastPageOffset: Double? = nil) {
        let realm = try! Realm()

        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        var reference: ChapterReference?

        switch chapter.sourceId {
        case STTHelpers.LOCAL_CONTENT_ID:
            let content = realm
                .objects(ArchivedContent.self)
                .where({ $0.id == chapter.contentId  && !$0.isDeleted  })
                .first
            reference = chapter.toStored().generateReference()
            reference?.archive = content
        case STTHelpers.OPDS_CONTENT_ID:
            let content = realm
                .objects(StreamableOPDSContent.self)
                .where { $0.id == chapter.id  && !$0.isDeleted }
                .first
            reference = chapter.toStored().generateReference()
            reference?.opds = content
        default:
            reference = chapter.toStored().generateReference()
            reference?.content = DataManager.shared.getStoredContent(id)
        }

        // Ensure Chapter Reference has been generated, Save Reference
        guard let reference else { return }

        try! realm.safeWrite {
            realm.add(reference, update: .modified)
        }

        // Target exists, save
        if let target {
            let prevMarkerID = target.currentChapter?.id
            try! realm.safeWrite {
                target.dateRead = .now
                target.lastPageRead = lastPageRead
                target.totalPageCount = totalPageCount
                target.lastPageOffset = lastPageOffset
                target.currentChapter = reference
            }

            if let prevMarkerID, prevMarkerID != chapter.id {
                validateChapterReference(id: prevMarkerID, realm)
            }
            DataManager.shared.updateLastRead(forId: id, realm)
            return
        }

        // Marker DNE, Create
        let marker = ProgressMarker()
        marker.id = id
        marker.dateRead = .now
        marker.currentChapter = reference
        marker.lastPageRead = lastPageRead
        marker.totalPageCount = totalPageCount
        marker.lastPageOffset = lastPageOffset

        try! realm.safeWrite {
            realm.add(marker, update: .modified)
        }
        DataManager.shared.updateLastRead(forId: id, realm)
    }

    func removeFromHistory(id: String) {
        let realm = try! Realm()
        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        guard let target else {
            return
        }
        try! realm.safeWrite {
            target.dateRead = nil // Simply Removes Date Value so keeps contents read marker.
        }
    }

    func bulkMarkChapters(for id: ContentIdentifier, chapters: [StoredChapter], markAsRead: Bool = true) {
        let realm = try! Realm()
        let nums = Set(chapters.map(\.number))

        defer {
            Task {
                let chapterIds = chapters.map { $0.chapterId }
                notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
            }
        }
        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id.id }
            .where { $0.isDeleted == false }
            .first

        // Has Marker, Update
        if let target {
            try! realm.safeWrite {
                if markAsRead { // Insert Into Set
                    target.readChapters.insert(objectsIn: nums)
                } else {
                    let set = MutableSet<Double>()
                    set.insert(objectsIn: nums)
                    target.readChapters.subtract(set)
                }
            }

            return
        }

        guard markAsRead else { // Marker DNE, If not marking as read, no point creating a marker
            return
        }

        let marker = ProgressMarker()
        marker.id = id.id
        marker.readChapters.insert(objectsIn: nums)
        marker.dateRead = nil

        try! realm.safeWrite {
            realm.add(marker)
        }
    }

    func markChaptersByNumber(for id: ContentIdentifier, chapters: Set<Double>, markAsRead: Bool = true) {
        let realm = try! Realm()

        defer {
            Task {
                let realm = try! Realm()

                // Get Chapters
                let chapterIds = realm
                    .objects(StoredChapter.self)
                    .where { $0.contentId == id.contentId }
                    .where { $0.sourceId == id.sourceId }
                    .where { $0.number.in(chapters) }
                    .map(\.chapterId) as [String]
                notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
            }
        }

        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id.id }
            .where { $0.isDeleted == false }
            .first

        // Has Marker, Update
        if let target {
            try! realm.safeWrite {
                if markAsRead { // Insert Into Set
                    target.readChapters.insert(objectsIn: chapters)
                } else {
                    let set = MutableSet<Double>()
                    set.insert(objectsIn: chapters)
                    target.readChapters.subtract(set)
                }
            }

            return
        }

        guard markAsRead else { // Marker DNE, If not marking as read, no point creating a marker
            return
        }

        let marker = ProgressMarker()
        marker.id = id.id
        marker.readChapters.insert(objectsIn: chapters)
        marker.dateRead = nil

        try! realm.safeWrite {
            realm.add(marker)
        }
    }

    func notifySourceOfMarkState(identifier: ContentIdentifier, chapters: [String], completed: Bool) {
        guard let source = SourceManager.shared.getSource(id: identifier.sourceId), source.intents.chapterEventHandler else {
            return
        }

        Task.detached {
            do {
                try await source.onChaptersMarked(contentId: identifier.contentId, chapterIds: chapters, completed: completed)
            } catch {
                Logger.shared.error("\(error)", source.name)
                ToastManager.shared.error(DSK.Errors.NamedError(name: source.name, message: "Failed to sync progress markers."))
            }
        }
    }
}
