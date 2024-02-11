//
//  Realm+ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getContentMarker(for id: String) -> ProgressMarker? {
        return getObject(of: ProgressMarker.self, with: id)
    }

    func getFrozenContentMarker(for id: String) -> ProgressMarker? {
        return getContentMarker(for: id)?.freeze()
    }

    func getMaxReadKey(for id: String) -> Double {
        getContentMarker(for: id)?.maxReadChapterKey ?? 0
    }

    private func getLatestLinkedMarker(for id: String) -> ProgressMarker? {
        let maxedMarker = getLinkedContent(for: id)
            .map { getContentMarker(for: $0.id) }
            .appending(getContentMarker(for: id))
            .compactMap { $0 }
            .max { lhs, rhs in
                (lhs.currentChapter?.chapterOrderKey ?? 0.0) < (rhs.currentChapter?.chapterOrderKey ?? 0.0)
            }

        return maxedMarker?
            .freeze()
    }

    func didCompleteChapter(chapter: ThreadSafeChapter) async {
        let id = chapter.STTContentIdentifier
        // Get Object
        let target = getContentMarker(for: id)

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

        await operation {
            realm.add(reference, update: .modified)
        }

        // Has Marker, Update
        if let target {
            let prevMarkerID = target.currentChapter?.id
            await operation {
                target.dateRead = .now
                target.lastPageRead = nil
                target.totalPageCount = nil
                target.lastPageOffsetPCT = nil
                target.readChapters.insert(chapter.chapterOrderKey)
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
        marker.readChapters.insert(chapter.chapterOrderKey)
        marker.currentChapter = reference

        await operation {
            realm.add(marker, update: .modified)
        }
        await decrementUnreadCount(for: id)
    }

    func updateContentProgress(chapter: ThreadSafeChapter, lastPageRead: Int, totalPageCount: Int, lastPageOffsetPCT: Double? = nil) async {
        let id = chapter.STTContentIdentifier
        // Get Object
        let target = getContentMarker(for: id)

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

        await operation {
            realm.add(reference, update: .modified)
        }

        // Target exists, save
        if let target {
            let prevMarkerID = target.currentChapter?.id
            await operation {
                target.dateRead = .now
                target.lastPageRead = lastPageRead
                target.totalPageCount = totalPageCount
                target.lastPageOffsetPCT = lastPageOffsetPCT
                target.currentChapter = reference

                if lastPageRead == totalPageCount {
                    target.readChapters.insert(chapter.chapterOrderKey)
                }
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
        marker.lastPageOffsetPCT = lastPageOffsetPCT
        if lastPageRead == totalPageCount {
            marker.readChapters.insert(chapter.chapterOrderKey)
        }

        await operation {
            realm.add(marker, update: .modified)
        }
        await updateLastRead(forId: id)
    }

    func removeFromHistory(id: String) async {
        // Get Object
        let target = getContentMarker(for: id)

        guard let target else {
            return
        }
        await operation {
            target.dateRead = nil // Simply Removes Date Value so keeps contents read marker.
        }
    }

    func bulkMarkChapters(for id: ContentIdentifier, chapters: [ThreadSafeChapter], markAsRead: Bool = true) async {
        let nums = Set(chapters.map(\.chapterOrderKey))

        defer {
            Task {
                let chapterIds = chapters.map { $0.chapterId }
                await notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
            }
        }
        
        defer {
            Task {
                await updateUnreadCount(for: id)
            }
        }
        
        // Get Object
        let target = getContentMarker(for: id.id)

        // Has Marker, Update
        if let target {
            await operation {
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

        await operation {
            realm.add(marker, update: .modified)
        }
    }

    func markChaptersByNumber(for id: ContentIdentifier, chapters: Set<Double>, markAsRead: Bool = true) async {
        defer {
            Task {
                // Get Chapters
                let chapterIds = realm
                    .objects(StoredChapter.self)
                    .where { $0.contentId == id.contentId }
                    .where { $0.sourceId == id.sourceId }
                    .toArray()
                    .filter { chapters.contains($0.chapterOrderKey) }
                    .map(\.chapterId)

                await notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
            }
        }
        
        defer {
            Task {
                await updateUnreadCount(for: id)
            }
        }

        let target = getContentMarker(for: id.id)

        // Has Marker, Update
        if let target {
            await operation {
                if markAsRead { // Insert Into Set
                    target.readChapters.insert(objectsIn: chapters)

                    // Update Progress if more
                    guard let chapter = target.currentChapter, let maxRead = chapters.max(), maxRead >= ThreadSafeChapter.orderKey(volume: chapter.volume, number: chapter.number) else { return }
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

        await operation {
            realm.add(marker, update: .modified)
        }
    }

    func notifySourceOfMarkState(identifier: ContentIdentifier, chapters: [String], completed: Bool) async {
        guard let source = await DSK.shared.getSource(id: identifier.sourceId), source.intents.chapterEventHandler else {
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
    func getMaxReadChapterOrderKey(id: String) -> Double {
        let maxReadOnTarget = getContentMarker(for: id)?.maxReadChapterKey ?? 0.0
        let maxReadOnLinked = getLinkedContent(for: id)
            .map { getContentMarker(for: $0.id)?.maxReadChapterKey ?? 0.0 }
            .max() ?? 0.0

        return max(maxReadOnTarget, maxReadOnLinked)
    }
}
