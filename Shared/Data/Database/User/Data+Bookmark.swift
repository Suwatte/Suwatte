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

        let bookmark = realm.objects(Bookmark.self)
            .where { $0.isDeleted == false }
            .where { $0.chapter.id == chapter.id }
            .where { $0.page == page }
            .first

        if let bookmark {
            try! realm.safeWrite {
                bookmark.isDeleted = true
            }
            validateChapterReference(id: chapter.id, realm)
        } else {
            let object = Bookmark()
            object.chapter = chapter.generateReference()
            object.page = page
            object.verticalOffset = offset
        }
    }
}
