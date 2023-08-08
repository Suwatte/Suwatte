//
//  Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import IceCream
import RealmSwift


extension DataManager {
    func validateChapterReference(id: String, _ realm: Realm? = nil) {
        let realm = try! realm ?? Realm()
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
        try! realm.safeWrite {
            target.isDeleted = true
        }
    }
}



extension DataManager {
    func getChapters(_ source: String, content: String) -> Results<StoredChapter> {
        let realm = try! Realm()

        return realm.objects(StoredChapter.self).where {
            $0.contentId == content &&
                $0.sourceId == source
        }
        .sorted(by: \.index, ascending: true)
    }

    func getStoredChapter(_ id: String) -> StoredChapter? {
        let realm = try! Realm()

        return realm.objects(StoredChapter.self)
            .where { $0.id == id }
            .first
    }

    func getLatestStoredChapter(_ sourceId: String, _ contentId: String) -> StoredChapter? {
        let realm = try! Realm()

        let chapter = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == contentId }
            .where { $0.sourceId == sourceId }
            .sorted(by: \.index, ascending: true)
            .first

        return chapter
    }

    func storeChapters(_ chapters: [StoredChapter]) {
        let realm = try! Realm()
        // Get Chapters to be deleted
        if let first = chapters.first {
            let idList = chapters.map { $0.chapterId }
            let toBeDeleted = realm
                .objects(StoredChapter.self)
                .where { $0.contentId == first.contentId }
                .where { $0.sourceId == first.sourceId }
                .where { !$0.chapterId.in(idList) }

            try! realm.safeWrite {
                realm.delete(toBeDeleted)
            }
        }

        // Upsert Chapters List
        try! realm.safeWrite {
            realm.add(chapters, update: .modified)
        }
    }
}
