//
//  +ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation

extension DaisukeEngine.Structs.ChapterData {
    func toStored(withStoredChapter chapter: StoredChapter) -> StoredChapterData {
        let object = StoredChapterData()
        object.chapter = chapter

        if let pages {
            for page in pages {
                let stored = StoredChapterPage()
                stored.url = page.url
                stored.raw = page.raw
                object.pages.append(stored)
            }
        }
        object.text = text
        return object
    }
}
