//
//  ThreadSafeChapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation

struct ThreadSafeChapter: Hashable {
    var id: String
    var sourceId: String
    var chapterId: String
    var contentId: String
    var index: Int
    var number: Double
    var volume: Double?
    var title: String?
    var language: String?
    var date: Date
    var webUrl: String?
    var thumbnail: String?

    func toStored() -> StoredChapter {
        let obj = StoredChapter()
        obj.id = id
        obj.contentId = contentId
        obj.sourceId = sourceId
        obj.chapterId = chapterId
        obj.index = index
        obj.number = number
        obj.volume = volume
        obj.title = title
        obj.language = language
        obj.date = date
        obj.webUrl = webUrl
        obj.thumbnail = thumbnail
        return obj
    }

    var sttId: String {
        ContentIdentifier(contentId: contentId, sourceId: sourceId).id
    }

    var chapterType: ReaderView.ReaderChapter.ChapterType {
        if sourceId == STTHelpers.LOCAL_CONTENT_ID { return .LOCAL }
        else if sourceId == STTHelpers.OPDS_CONTENT_ID { return .OPDS }
        else { return .EXTERNAL }
    }

    var displayName: String {
        var str = ""
        if let volume = volume, volume != 0 {
            str += "Volume \(volume.clean)"
        }
        str += " Chapter \(number.clean)"
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
