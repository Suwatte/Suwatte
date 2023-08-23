//
//  +Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation

extension StoredChapter {
    func toThreadSafe() -> ThreadSafeChapter {
        return .init(id: id, sourceId: sourceId, chapterId: chapterId, contentId: contentId, index: index, number: number, volume: volume, title: title, language: language, date: date, webUrl: webUrl, thumbnail: thumbnail)
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

extension StoredChapter {
    static func == (lhs: StoredChapter, rhs: StoredChapter) -> Bool {
        lhs.id == rhs.id
    }
}

enum ChapterType {
    case EXTERNAL, LOCAL, OPDS
}
