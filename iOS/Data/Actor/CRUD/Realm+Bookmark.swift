//
//  Realm+Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func isBookmarked(chapter: StoredChapter, page: Int) -> Bool {
        return !realm.objects(Bookmark.self)
            .where { $0.isDeleted == false }
            .where { $0.chapter.id == chapter.id }
            .where { $0.page == page }
            .isEmpty
    }

    func toggleBookmark(chapter: StoredChapter, page: Int, offset: Double? = nil) async {
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
            try! await realm.asyncWrite {
                bookmarks.forEach {
                    $0.isDeleted = true
                }
            }
            await validateChapterReference(id: chapter.id)
            return
        }

        // Create new bookmark
        let object = Bookmark()
        object.chapter = chapter.generateReference()
        object.chapter?.content = getStoredContent(chapter.contentIdentifier.id)
        object.page = page
        object.verticalOffset = offset
        try! await realm.asyncWrite {
            realm.add(object, update: .modified)
        }
    }

    func removeBookmark(_ id: String) async {
        let target = realm
            .objects(Bookmark.self)
            .where { $0.id == id }
            .first

        guard let target else {
            return
        }

        try! await realm.asyncWrite {
            target.isDeleted = false
        }
    }
}
