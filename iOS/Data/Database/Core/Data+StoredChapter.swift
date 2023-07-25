//
//  Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import IceCream
import RealmSwift

extension StoredChapter {
    func toThreadSafe() -> ThreadSafeChapter {
        return .init(id: id, sourceId: sourceId, chapterId: chapterId, contentId: contentId, index: index, number: number, volume: volume, title: title, language: language, date: date, webUrl: webUrl, thumbnail: thumbnail)
    }
}

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
    func getChapterType(for id: String) -> ReaderView.ReaderChapter.ChapterType {
        if id == STTHelpers.LOCAL_CONTENT_ID { return .LOCAL }
        else if id == STTHelpers.OPDS_CONTENT_ID { return .OPDS }
        else { return .EXTERNAL }
    }
}

extension StoredChapter {
    func generateReference() -> ChapterReference {
        let object = ChapterReference()
        object.id = id
        object.chapterId = chapterId
        object.number = number
        object.volume = volume
        return object
    }
}

extension DaisukeEngine.Structs.Chapter {
    func toStoredChapter(withSource sourceId: String) -> StoredChapter {
        let chapter = StoredChapter()

        chapter.id = "\(sourceId)||\(contentId)||\(chapterId)"

        chapter.sourceId = sourceId
        chapter.contentId = contentId
        chapter.chapterId = chapterId

        chapter.number = number
        chapter.volume = (volume == nil || volume == 0.0) ? nil : volume
        chapter.title = title
        chapter.language = language

        chapter.date = date
        chapter.index = index
        chapter.webUrl = webUrl

        let providers = providers?.map { provider -> ChapterProvider in
            let links = provider.links?.map { link -> ChapterProviderLink in
                let l = ChapterProviderLink()
                l.url = link.url
                l.type = link.type
                return l
            }

            let p = ChapterProvider()

            if let links {
                p.links.append(objectsIn: links)
            }
            p.name = provider.name
            p.id = provider.id
            return p
        } ?? []
        chapter.providers.append(objectsIn: providers)
        return chapter
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
