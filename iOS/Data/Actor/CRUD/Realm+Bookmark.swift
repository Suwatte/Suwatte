//
//  Realm+Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import IceCream
import RealmSwift
import UIKit

extension RealmActor {
    func addBookmark(for chapter: ThreadSafeChapter, at page: Int, with image: UIImage, on offset: Double? = nil) async -> Bool {
        let image = image.imageFlippedForRightToLeftLayoutDirection()
        guard let data = image.pngData() ?? image.jpegData(compressionQuality: 1) else {
            Logger.shared.error("Invalid Image Data")
            return false
        }

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
            reference?.content = getStoredContent(chapter.STTContentIdentifier)
        }

        guard let reference, reference.isValid else {
            Logger.shared.error("Invalid Chapter Reference")
            return false
        }

        let bookmark = UpdatedBookmark()
        bookmark.chapter = reference
        bookmark.page = page
        bookmark.pageOffsetPCT = offset
        bookmark.dateAdded = .now
        bookmark.asset = CreamAsset.create(object: bookmark,
                                           folder: "bookmark",
                                           data: data)
        await operation {
            realm.add(bookmark, update: .all)
        }
        return true
    }

    func removeBookmark(_ id: String) async {
        let target = realm
            .objects(UpdatedBookmark.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        guard let target else {
            return
        }

        await operation {
            target.isDeleted = true
        }
    }
}


extension RealmActor {
    func toggleBookmark(for chapter: ThreadSafeChapter) async -> Bool {
        
        let target = realm
            .objects(ChapterBookmark.self)
            .where { !$0.isDeleted && $0.id == chapter.id }
            .first
        
        if let target {
            await operation {
                target.isDeleted = true
            }
            await validateChapterReference(id: target.id)
            return false
        }
        
        let reference = chapter.toStored().generateReference()
        
        let object = ChapterBookmark()
        object.id = chapter.id
        object.chapter = reference
        
        await operation {
            realm.add(object, update: .modified)
        }
        
        return true
    }
}
