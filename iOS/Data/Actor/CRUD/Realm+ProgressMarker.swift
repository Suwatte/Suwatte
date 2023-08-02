//
//  Realm+ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift
import Foundation

extension RealmActor {
    func getContentMarker(for id: String) -> ProgressMarker? {
        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        return target
    }

    func getLatestLinkedMarker(for id: String) -> ProgressMarker? {
        let maxedMarker = getLinkedContent(for: id)
            .map { getContentMarker(for: $0.id) }
            .appending(getContentMarker(for: id))
            .compactMap { $0 }
            .max { lhs, rhs in
                (lhs.currentChapter?.number ?? 0.0) < (rhs.currentChapter?.number ?? 0.0)
            }

        return maxedMarker?
            .freeze()
    }

    func didCompleteChapter(for id: String, chapter: ThreadSafeChapter) async {

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
                .where { $0.id == chapter.contentId && !$0.isDeleted }
                .first
            reference = chapter.toStored().generateReference()
            reference?.archive = content
        case STTHelpers.OPDS_CONTENT_ID:
            let content = realm
                .objects(StreamableOPDSContent.self)
                .where { $0.id == chapter.id && !$0.isDeleted }
                .first
            reference = chapter.toStored().generateReference()
            reference?.opds = content
        default:
            reference = chapter.toStored().generateReference()
            reference?.content = getStoredContent(id)
        }

        // Ensure Chapter Reference has been generated, Save Reference
        let hasValidReference = reference?.content != nil || reference?.archive != nil || reference?.opds != nil
        guard let reference, hasValidReference else { return }

        try! await realm.asyncWrite {
            realm.add(reference, update: .modified)
        }

        // Has Marker, Update
        if let target {
            let prevMarkerID = target.currentChapter?.id
            try! await realm.asyncWrite {
                target.dateRead = .now
                target.lastPageRead = nil
                target.totalPageCount = nil
                target.lastPageOffset = nil
                target.readChapters.insert(chapter.number)
                target.currentChapter = reference
            }

            if let prevMarkerID, prevMarkerID != chapter.id {
                await validateChapterReference(id: prevMarkerID)
            }
            await decrementUnreadCount(for: id)

            return
        }

        // Marker DNE, Create

        let marker = ProgressMarker()
        marker.id = id
        marker.readChapters.insert(chapter.number)
        marker.currentChapter = reference

        try! await realm.asyncWrite {
            realm.add(marker, update: .modified)
        }
        await decrementUnreadCount(for: id)
    }

    func updateContentProgress(for id: String, chapter: ThreadSafeChapter, lastPageRead: Int, totalPageCount: Int, lastPageOffset: Double? = nil) async {

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
                .where { $0.id == chapter.contentId && !$0.isDeleted }
                .first
            reference = chapter.toStored().generateReference()
            reference?.archive = content
        case STTHelpers.OPDS_CONTENT_ID:
            let content = realm
                .objects(StreamableOPDSContent.self)
                .where { $0.id == chapter.id && !$0.isDeleted }
                .first
            reference = chapter.toStored().generateReference()
            reference?.opds = content
        default:
            reference = chapter.toStored().generateReference()
            reference?.content = getStoredContent(id)
        }

        // Ensure Chapter Reference has been generated, Save Reference
        guard let reference, reference.isValid else { return }

        try! await realm.asyncWrite {
            realm.add(reference, update: .modified)
        }

        // Target exists, save
        if let target {
            let prevMarkerID = target.currentChapter?.id
            try! await realm.asyncWrite {
                target.dateRead = .now
                target.lastPageRead = lastPageRead
                target.totalPageCount = totalPageCount
                target.lastPageOffset = lastPageOffset
                target.currentChapter = reference
            }

            if let prevMarkerID, prevMarkerID != chapter.id {
               await validateChapterReference(id: prevMarkerID)
            }
            await updateLastRead(forId: id)
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

        try! await realm.asyncWrite {
            realm.add(marker, update: .modified)
        }
        await updateLastRead(forId: id)
    }

    func removeFromHistory(id: String) async {
        // Get Object
        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first

        guard let target else {
            return
        }
        try! await realm.asyncWrite {
            target.dateRead = nil // Simply Removes Date Value so keeps contents read marker.
        }
    }

    func bulkMarkChapters(for id: ContentIdentifier, chapters: [StoredChapter], markAsRead: Bool = true) async {
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
            try! await realm.asyncWrite {
                if markAsRead { // Insert Into Set
                    target.readChapters.insert(objectsIn: nums)
                } else {
                    nums.forEach {
                        target.readChapters.remove($0)
                    }
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

        try! await realm.asyncWrite {
            realm.add(marker)
        }
    }

    func markChaptersByNumber(for id: ContentIdentifier, chapters: Set<Double>, markAsRead: Bool = true) async {
        defer {
            // Get Chapters
            let chapterIds = realm
                .objects(StoredChapter.self)
                .where { $0.contentId == id.contentId }
                .where { $0.sourceId == id.sourceId }
                .where { $0.number.in(chapters) }
                .map(\.chapterId) as [String]
            notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
        }

        let target = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id.id }
            .where { $0.isDeleted == false }
            .first

        // Has Marker, Update
        if let target {
            try! await realm.asyncWrite {
                if markAsRead { // Insert Into Set
                    target.readChapters.insert(objectsIn: chapters)

                    // Update Progress if more
                    guard let chapter = target.currentChapter, let maxRead = chapters.max(), maxRead >= chapter.number else { return }
                    target.totalPageCount = 1
                    target.lastPageRead = 1
                } else {
                    chapters.forEach {
                        target.readChapters.remove($0)
                    }
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

        try! await realm.asyncWrite {
            realm.add(marker)
        }
    }

    func notifySourceOfMarkState(identifier: ContentIdentifier, chapters: [String], completed: Bool) {
        guard let source = DSK.shared.getSource(id: identifier.sourceId), source.intents.chapterEventHandler else {
            return
        }

        Task.detached {
            do {
                try await source.onChaptersMarked(contentId: identifier.contentId, chapterIds: chapters, completed: completed)
            } catch {
                Logger.shared.error("\(error)", source.id)
                ToastManager.shared.error(DSK.Errors.NamedError(name: source.name, message: "Failed to sync progress markers."))
            }
        }
    }
}

extension RealmActor {
    /// Fetches the highest marked chapter with respect to content links
    func getHighestMarkedChapter(id: String) -> Double {
        let maxReadOnTarget = getContentMarker(for: id)?.maxReadChapter ?? 0.0
        let maxReadOnLinked = getLinkedContent(for: id)
            .map { getContentMarker(for: $0.id)?.maxReadChapter ?? 0.0 }
            .max() ?? 0.0

        return max(maxReadOnTarget, maxReadOnLinked)
    }
}
