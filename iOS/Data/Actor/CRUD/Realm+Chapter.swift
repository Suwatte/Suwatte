//
//  Realm+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift

extension RealmActor {
    @MainActor
    func getChapterType(for id: String) -> ReaderView.ReaderChapter.ChapterType {
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
            .objects(Bookmark.self)
            .where { $0.isDeleted == false && $0.chapter.id == id }
            .isEmpty

        let hasMarker = !realm
            .objects(ProgressMarker.self)
            .where { $0.isDeleted == false && $0.currentChapter.id == id }
            .isEmpty

        guard !hasBookmarks, !hasMarker else {
            return
        }
        // Has no references, delete.
        try! await realm.asyncWrite {
            target.isDeleted = true
        }
    }
}


extension RealmActor {
    func getChapters(_ source: String, content: String) -> [StoredChapter] {
        realm.objects(StoredChapter.self)
        .where { $0.contentId == content }
        .where { $0.sourceId == source }
        .sorted(by: \.index, ascending: true)
        .freeze()
        .toArray()
    }

    func getStoredChapter(_ id: String) -> StoredChapter? {
        return realm.objects(StoredChapter.self)
            .where { $0.id == id }
            .first
    }

    func getLatestStoredChapter(_ sourceId: String, _ contentId: String) -> StoredChapter? {
        let chapter = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == contentId }
            .where { $0.sourceId == sourceId }
            .sorted(by: \.index, ascending: true)
            .first

        return chapter
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

            try! await realm.asyncWrite {
                realm.delete(toBeDeleted)
            }
        }

        // Upsert Chapters List
        try! await realm.asyncWrite {
            realm.add(chapters, update: .modified)
        }
    }
}
