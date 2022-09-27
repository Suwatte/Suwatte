//
//  Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

final class StoredChapter: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: String

    // Identifiers
    @Persisted(indexed: true) var sourceId: String
    @Persisted(indexed: true) var chapterId: String
    @Persisted(indexed: true) var contentId: String

    @Persisted var index: Int

    @Persisted var number: Double
    @Persisted var volume: Double?
    @Persisted var title: String?
    @Persisted var language: String?
    @Persisted var date: Date

    @Persisted var webUrl: String?

    @Persisted var providers: List<ChapterProvider>

    var displayName: String {
        var str = ""
        if let volume = volume, volume != 0 {
            str += "Volume \(volume.clean)"
        }
        str += " Chapter \(number.clean)"
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var chapterName: String {
        "Chapter \(number.clean)"
    }

    var SourceName: String {
        DaisukeEngine.shared.getSource(with: sourceId)?.name ?? "Unrecognized : \(sourceId)"
    }

    var ContentIdentifer: String {
        DaisukeEngine.Structs.SuwatteContentIdentifier(contentId: contentId, sourceId: sourceId).id
    }

    var chapterType: ReaderView.ReaderChapter.ChapterType {
        if sourceId == STTHelpers.LOCAL_CONTENT_ID { return .LOCAL }
        else if sourceId.contains(STTHelpers.OPDS_CONTENT_ID) { return .OPDS }
        else { return .EXTERNAL }
    }
}

extension DaisukeEngine.Structs.Chapter {
    func toStoredChapter(withSource source: DaisukeEngine.ContentSource) -> StoredChapter {
        let chapter = StoredChapter()

        chapter._id = "\(source.id)||\(contentId)||\(chapterId)"

        chapter.sourceId = source.id
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
            let links = provider.links.map { link -> ChapterProviderLink in
                let l = ChapterProviderLink()
                l.url = link.url
                l.type = link.type
                return l
            }

            let p = ChapterProvider()
            p.links.append(objectsIn: links)
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
    
    func getLatestStoredChapter(_ sourceId: String, _ contentId: String)-> StoredChapter? {
        let realm = try! Realm()
        
        let chapter = realm
            .objects(StoredChapter.self)
            .where({ $0.contentId == contentId })
            .where({ $0.sourceId == sourceId })
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
