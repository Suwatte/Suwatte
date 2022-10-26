//
//  LibraryChapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

final class ChapterMarker: Object, ObjectKeyIdentifiable {
    // Identifier
    @Persisted(primaryKey: true) var _id: String
    @Persisted var chapter: StoredChapter? {
        didSet {
            if let chapter = chapter {
                _id = chapter._id
            }
        }
    }

    @Persisted var dateRead: Date?

    // Progress
    @Persisted var lastPageRead: Int
    @Persisted var totalPageCount: Int
    @Persisted var completed: Bool
    var progress: Double {
        Double(lastPageRead) / Double(totalPageCount)
    }

    var pctProgress: Double {
        progress * 100.0
    }

    @Persisted var lastPageOffset: Double?
}

extension DataManager {
    func getLatestMarker(contentId: String, sourceId: String) -> ChapterMarker? {
        let realm = try! Realm()

        return realm.objects(ChapterMarker.self)
            .filter {
                $0.chapter != nil && $0.chapter!.contentId == contentId && $0.chapter!.sourceId == sourceId && $0.dateRead != nil
            }
            .sorted(by: { $0.dateRead! > $1.dateRead! })
            .first
    }

    func getChapterMarker(forId id: String) -> ChapterMarker? {
        let realm = try! Realm()

        return realm.objects(ChapterMarker.self).first(where: { $0._id == id })
    }

    // Mark a list of chapters as read or unread
    func bulkMarkChapter(chapters: [StoredChapter], completed: Bool = true) {
        let realm = try! Realm()

        let objects = chapters.map { chapter -> [String: Any] in
            ["chapter": chapter as Any, "completed": completed, "_id": chapter._id]
        }
        try! realm.safeWrite {
            for object in objects {
                realm.create(ChapterMarker.self, value: object, update: .modified)
            }
        }

        notifySourceOfMarkState(chapters: chapters, completed: completed)
    }

    private func notifySourceOfMarkState(chapters: [StoredChapter], completed: Bool) {
        let grouped = Dictionary(grouping: chapters, by: { $0.sourceId })
        for (key, value) in grouped {
            let source = DaisukeEngine.shared.getJSSource(with: key)
            let groupedByContent = Dictionary(grouping: value, by: { $0.contentId })

            for (k, v) in groupedByContent {
                let t = v.map { $0.chapterId }
                Task {
                    await source?.onChaptersMarked(contentId: k, chapterIds: t, completed: completed)
                }
            }
        }
    }

    func getHighestMarked(id: ContentIdentifier) -> StoredChapter? {
        let realm = try! Realm()

        return realm
            .objects(ChapterMarker.self)
            .where { $0.chapter.contentId == id.contentId }
            .where { $0.chapter.sourceId == id.sourceId }
            .where { $0.completed == true }
            .sorted(by: \.chapter?.index)
            .first?
            .chapter
    }

    func setProgress(from chapter: ReaderView.ReaderChapter, isNovel: Bool = false) {
        let realm = try! Realm()

        let last = chapter.requestedPageIndex + 1
        var lastOffset: Double?
        if let offset = chapter.requestedPageOffset {
            lastOffset = Double(offset)
        }
        let total = !isNovel ? chapter.pages?.count ?? 0 : chapter.data.value?.pages.count ?? 0
        let marker = ChapterMarker()
        marker.chapter = chapter.chapter
        marker.dateRead = Date()
        marker.lastPageRead = last
        marker.totalPageCount = total
        marker.completed = false
        marker.lastPageOffset = lastOffset

        try! realm.safeWrite {
            realm.add(marker, update: .all)
        }
    }

    func setProgress(chapter: StoredChapter, completed: Bool = true) {
        let realm = try! Realm()

        var target: ChapterMarker?
        target = realm.objects(ChapterMarker.self).first(where: { $0._id == chapter._id })

        if target == nil {
            target = ChapterMarker()
            target?.chapter = chapter
        }

        if let target = target {
            try! realm.safeWrite {
                target.completed = completed
                if completed {
                    target.totalPageCount = 0
                    target.lastPageRead = 0
                }
                realm.add(target, update: .modified)
            }
        }
    }
}
