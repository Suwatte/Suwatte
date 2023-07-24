//
//  Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

extension DataManager {
    func isBookmarked(chapter: StoredChapter, page: Int) -> Bool {
        let realm = try! Realm()

        return !realm.objects(Bookmark.self)
            .where { $0.isDeleted == false }
            .where { $0.chapter.id == chapter.id }
            .where { $0.page == page }
            .isEmpty
    }

    func toggleBookmark(chapter: StoredChapter, page: Int, offset: Double? = nil) {
        let realm = try! Realm()

        var bookmarks = realm.objects(Bookmark.self)
            .where { $0.isDeleted == false }
            .where { $0.chapter.id == chapter.id }
            .where { $0.page == page }

        if let offset {
            let max = offset + 250
            let min = offset - 250
            bookmarks = bookmarks
                .where { $0.verticalOffset == nil || ($0.verticalOffset >= min && $0.verticalOffset <= max) }
        }

        if !bookmarks.isEmpty {
            try! realm.safeWrite {
                bookmarks.forEach {
                    $0.isDeleted = true
                }
            }
            validateChapterReference(id: chapter.id, realm)
            return
        }

        // Create new bookmark
        let object = Bookmark()
        object.chapter = chapter.generateReference()
        object.chapter?.content = getStoredContent(chapter.contentIdentifier.id)
        object.page = page
        object.verticalOffset = offset
        try! realm.safeWrite {
            realm.add(object, update: .modified)
        }
    }

    func removeBookmark(_ id: String) {
        let realm = try! Realm()

        let target = realm
            .objects(Bookmark.self)
            .where { $0.id == id }
            .first

        guard let target else {
            return
        }

        try! realm.safeWrite {
            target.isDeleted = false
        }
    }
}
