//
//  Realm+ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getContentMarkers(for contentIdentifier: ContentIdentifier) -> Results<ProgressMarker> {
        let progressMarkers = realm
            .objects(ProgressMarker.self)
            .where { $0.id.starts(with: contentIdentifier.id + "||", options: []) && $0.isDeleted == false }

        return progressMarkers
    }

    func getFrozenContentMarkers(for contentIdentifier: ContentIdentifier, completed: Bool? = nil) -> [ProgressMarker] {
        var progressMarkers = getContentMarkers(for: contentIdentifier)
        if completed != nil {
            let pred = NSPredicate(format: "chapter != null && isDeleted == false && \(completed! ? "" : "not")(totalPageCount >= 1 && lastPageRead == totalPageCount)")
            progressMarkers = progressMarkers
                .filter(pred)
        }

        return progressMarkers
            .freeze()
            .toArray()
    }

    func getFrozenContentMarker(for chapterId: String) -> ProgressMarker? {
        let progressMarker = realm
            .objects(ProgressMarker.self)
            .where { $0.id == chapterId && !$0.isDeleted }
            .freeze()
            .first

        return progressMarker
    }

    func getContentMarker(for chapterId: String) -> ProgressMarker? {
        return getObject(of: ProgressMarker.self, with: chapterId)
    }

    func getLatestReadContentMarker(for contentIdentifier: ContentIdentifier) -> ProgressMarker? {
        let latestReadContentMarker = getContentMarkers(for: contentIdentifier)
            .sorted(by: \.dateRead, ascending: false)
            .first

        guard latestReadContentMarker?.dateRead != nil else {
            return getMaxReadContentMarker(for: contentIdentifier)
        }

        return latestReadContentMarker
    }

    func getFrozenLatestReadContentMarker(for contentIdentifier: ContentIdentifier) -> ProgressMarker? {
        return getLatestReadContentMarker(for: contentIdentifier)?.freeze()
    }

    func getMaxReadContentMarker(for contentIdentifier: ContentIdentifier, completed: Bool? = nil) -> ProgressMarker? {
        return getFrozenContentMarkers(for: contentIdentifier, completed: completed)
            .max(by: \.chapter!.chapterOrderKey)
    }

    func getMaxReadKey(for contentIdentifier: ContentIdentifier, completed: Bool? = nil) -> Double {
        getMaxReadContentMarker(for: contentIdentifier, completed: completed)?.chapter?.chapterOrderKey ?? 0
    }

    func didCompleteChapter(chapter: ThreadSafeChapter) async {
        let contentId = chapter.STTContentIdentifier

        let reference: ChapterReference? = chapter.toStored().generateReference()
        switch chapter.sourceId {
            case STTHelpers.LOCAL_CONTENT_ID:
                reference?.archive = getArchivedContentInfo(chapter.contentId, freezed: false)
            case STTHelpers.OPDS_CONTENT_ID:
                reference?.opds = getPublication(id: chapter.id, freezed: false)
            default:
                reference?.content = getObject(of: StoredContent.self, with: chapter.STTContentIdentifier)
        }

        guard let reference, reference.isValid else {
            Logger.shared.error("Invalid Chapter Reference")
            return
        }
        
        await operation {
            realm.add(reference, update: .modified)
        }

        // Marker DNE -> Create, Has Marker -> Update
        let marker = ProgressMarker()
        marker.id = chapter.id
        marker.chapter = reference
        marker.setCompleted()

        await operation {
            realm.add(marker, update: .modified)
        }

        await decrementUnreadCount(for: contentId)
    }

    func updateContentProgress(chapter: ThreadSafeChapter, lastPageRead: Int, totalPageCount: Int, lastPageOffsetPCT: Double? = nil) async {
        let id = chapter.STTContentIdentifier
        
        let reference: ChapterReference? = chapter.toStored().generateReference()
        switch chapter.sourceId {
            case STTHelpers.LOCAL_CONTENT_ID:
                reference?.archive = getArchivedContentInfo(chapter.contentId, freezed: false)
            case STTHelpers.OPDS_CONTENT_ID:
                reference?.opds = getPublication(id: chapter.id, freezed: false)
            default:
                reference?.content = getStoredContent(id)
        }

        guard let reference, reference.isValid else {
            Logger.shared.error("Invalid Chapter Reference")
            return
        }

        await operation {
            realm.add(reference, update: .modified)
        }

        // Marker DNE -> Create, Marker exists -> save
        let marker = ProgressMarker()
        marker.id = reference.id
        marker.chapter = reference
        marker.dateRead = .now
        marker.lastPageRead = lastPageRead
        marker.totalPageCount = totalPageCount
        marker.lastPageOffsetPCT = lastPageOffsetPCT

        await operation {
            realm.add(marker, update: .modified)
        }

        await updateLastRead(forId: id)
    }

    func removeFromHistory(contentId: String) async {
        let collection = realm
                .objects(ProgressMarker.self)
                .where { $0.chapter.contentId == contentId && !$0.isDeleted }

        guard !collection.isEmpty else {
            return
        }
        await operation {
            for marker in collection {
                marker.dateRead = nil // Simply Removes Date Value so keeps contents read marker.
            }
        }
    }

    func markChaptersByNumber(for id: ContentIdentifier, chapters: Set<Double>, markAsRead: Bool = true) async {
        // Get Chapters
        let filteredChapters =
            realm
            .objects(StoredChapter.self)
            .where { $0.contentId == id.contentId && $0.sourceId == id.sourceId }
            .toArray()
            .filter { chapters.contains($0.chapterOrderKey) }
            .map { $0.toThreadSafe() }

        await markChapters(for: id, chapters: filteredChapters, markAsRead: markAsRead)
    }

    func markChapters(for id: ContentIdentifier, chapters: [ThreadSafeChapter], markAsRead: Bool = true) async {
        defer {
            Task {
                let chapterIds = chapters.map(\.chapterId)
                await notifySourceOfMarkState(identifier: id, chapters: chapterIds, completed: markAsRead)
            }
        }

        defer {
            Task {
                await updateUnreadCount(for: id)
            }
        }

        await operation {
            for chapter in chapters {
                let reference: ChapterReference? = chapter.toStored().generateReference()
                switch chapter.sourceId {
                    case STTHelpers.LOCAL_CONTENT_ID:
                        reference?.archive = getArchivedContentInfo(chapter.contentId, freezed: false)
                    case STTHelpers.OPDS_CONTENT_ID:
                        reference?.opds = getPublication(id: chapter.id, freezed: false)
                    default:
                        reference?.content = getStoredContent(chapter.STTContentIdentifier)
                }

                guard let reference, reference.isValid else {
                    Logger.shared.error("Invalid Chapter Reference")
                    continue
                }

                realm.add(reference, update: .modified)
                
                let marker = ProgressMarker()
                marker.id = chapter.id
                marker.chapter = reference
                marker.dateRead = Date.now

                if (markAsRead) {
                    marker.setCompleted()
                }
                else {
                    marker.isDeleted = true
                }

                realm.add(marker, update: .modified)
            }
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
    func getMaxReadChapterOrderKey(for contentIdentifier: ContentIdentifier, completed: Bool? = nil) -> Double {
        let maxReadOnTarget = getMaxReadKey(for: contentIdentifier, completed: completed)
        let maxReadOnLinked =
            getLinkedContent(for: contentIdentifier.id)
            .map { getMaxReadKey(for: $0.ContentIdentifier, completed: completed) }
            .max() ?? 0.0

        return max(maxReadOnTarget, maxReadOnLinked)
    }
}
