//
//  Realm+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift

extension RealmActor {
    @MainActor
    func getChapterType(for id: String) -> ChapterType {
        if id == STTHelpers.LOCAL_CONTENT_ID { return .LOCAL }
        else if id == STTHelpers.OPDS_CONTENT_ID { return .OPDS }
        else { return .EXTERNAL }
    }
}

extension RealmActor {
    func validateChapterReference(id: String) async {
        let target = realm
            .objects(ChapterReference.self)
            .where { $0.id == id && $0.isDeleted == false }
            .first

        guard let target else {
            return
        }

        // Check if it has any references
        let hasBookmarks = !realm
            .objects(UpdatedBookmark.self)
            .where { $0.isDeleted == false && $0.chapter.id == id }
            .isEmpty

        let hasChapterBookmarks = !realm
            .objects(ChapterReference.self)
            .where { !$0.isDeleted && $0.id == id }
            .isEmpty

        let hasMarker = !realm
            .objects(ProgressMarker.self)
            .where { $0.isDeleted == false && $0.id == id }
            .isEmpty

        guard !hasBookmarks, !hasMarker, !hasChapterBookmarks else {
            return
        }
        // Has no references, delete.
        await operation {
            target.isDeleted = true
        }
    }

    private func getStoredChapter(_ id: String) -> StoredChapter? {
        return realm.object(ofType: StoredChapter.self, forPrimaryKey: id)
    }
}

extension RealmActor {
    func getStoredChapterCount(_ sourceId: String, _ contentId: String) -> Int {
        realm
            .objects(StoredChapter.self)
            .count { $0.contentId == contentId && $0.sourceId == sourceId}
    }

    func getLatestStoredChapter(_ sourceId: String, _ contentId: String) -> StoredChapter? {
        let chapter = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == contentId }
            .where { $0.sourceId == sourceId }
            .sorted(by: \.index, ascending: true)
            .first?
            .freeze()

        return chapter
    }

    func getFrozenChapter(_ id: String) -> StoredChapter? {
        getStoredChapter(id)?.freeze()
    }

    func getChapters(_ source: String, content: String) -> [StoredChapter] {
        realm.objects(StoredChapter.self)
            .where { $0.contentId == content }
            .where { $0.sourceId == source }
            .sorted(by: \.index, ascending: true)
            .freeze()
            .toArray()
    }

    func storeChapters(_ chapters: [StoredChapter]) async {
        // Get Chapters to be deleted
        if let first = chapters.first {
            let idList = chapters.map { $0.chapterId }
            let toBeDeleted = realm
                .objects(StoredChapter.self)
                .where { $0.contentId == first.contentId }
                .where { $0.sourceId == first.sourceId }
                .where { !$0.chapterId.in(idList) }

            await operation {
                realm.delete(toBeDeleted)
            }
        }

        // Upsert Chapters List
        await operation {
            realm.add(chapters, update: .modified)
        }
    }
}
