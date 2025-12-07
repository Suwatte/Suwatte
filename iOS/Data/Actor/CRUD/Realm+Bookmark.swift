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
        let processor = await NukeDownsampleProcessor(width: UIScreen.main.bounds.width / 2, scale: await UIScreen.main.scale)
        let processedImage = processor.process(image)

        guard let data = processedImage?.pngData() ?? image.pngData() ?? image.jpegData(compressionQuality: 1) else {
            Logger.shared.error("Invalid Image Data")
            return false
        }

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
            return false
        }

        await operation {
            realm.add(reference, update: .modified)
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
            return false
        }

        let object = ChapterBookmark()
        object.id = chapter.id
        object.chapter = reference

        await operation {
            realm.add(object, update: .modified)
        }

        return true
    }
}
