//
//  ThreadSafeChapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation

struct ThreadSafeChapter: Hashable, Identifiable {
    let id: String
    let sourceId: String
    let chapterId: String
    let contentId: String
    let index: Int
    let number: Double
    let volume: Double?
    let title: String?
    let language: String
    let date: Date
    let webUrl: String?
    let thumbnail: String?
    var providers: [DSKCommon.ChapterProvider]?


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

    var STTContentIdentifier: String {
        ContentIdentifier(contentId: contentId, sourceId: sourceId).id
    }
    
    var isInternal: Bool {
        STTHelpers.isInternalSource(sourceId)
    }

    var chapterType: ChapterType {
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
    
    var chapterName: String {
        "Chapter \(number.clean)"
    }

    var contentIdentifier: ContentIdentifier {
        .init(contentId: contentId, sourceId: sourceId)
    }
    
    var inferredVolume: Double {
        volume ?? 999
    }
    var chapterOrderKey: Double {
        let d = inferredVolume * 1000
        return d + number
    }
    
    static func vnPair(from key: Double) -> (Double?, Double) {
        let inferredVolume = floor(key / 1000)
        let number = key.truncatingRemainder(dividingBy: 1000)
        
        let volume: Double? = inferredVolume == 999 ? nil : inferredVolume
        
        return (volume, number)
    }
    
    static func orderKey(volume: Double?, number: Double) -> Double {
        let d = (volume  ?? 99) * 1000
        return d + number
    }
}
