//
//  Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

final class Bookmark: Object {
    @Persisted var marker: ChapterMarker?
    @Persisted var page: Int
    @Persisted var dateAdded: Date
    @Persisted(primaryKey: true) var _id: String
}

extension Bookmark: ObjectKeyIdentifiable {}

extension DataManager {
    func isBookmarked(chapter: StoredChapter, page: Int) -> Bool {
        let realm = try! Realm()

        return realm.objects(Bookmark.self).contains {
            $0._id == "\(chapter._id)||\(page)"
        }
    }

    func toggleBookmark(chapter: StoredChapter, page: Int) {
        let realm = try! Realm()

        if let target = realm.objects(Bookmark.self).first(where: {
            $0._id == "\(chapter._id)||\(page)"
        }) {
            try! realm.safeWrite {
                realm.delete(target)
            }
            return
        }

        // Get Chapter marker

        var marker = realm.objects(ChapterMarker.self).first {
            $0._id == chapter._id
        }

        // marker not found, create
        if marker == nil {
            marker = ChapterMarker()
            marker?.chapter = chapter.thaw()

            if let marker = marker {
                try! realm.safeWrite {
                    realm.add(marker)
                }
            }
        }

        let bookmark = Bookmark()
        bookmark.marker = marker
        bookmark.page = page
        bookmark._id = "\(chapter._id)||\(page)"

        try! realm.safeWrite {
            realm.add(bookmark)
        }
    }
}
