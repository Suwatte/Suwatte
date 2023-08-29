//
//  ThreadSafeChapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation

protocol STTChapterObject {
    var number: Double { get }
    var volume: Double? { get }
    var language: String { get }
    var providers: [DSKCommon.ChapterProvider]? { get }
}

struct ThreadSafeChapter: Hashable, Identifiable, STTChapterObject {
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
    
    static var placeholder: Self {
        .init(id: "", sourceId: "", chapterId: "", contentId: "", index: 0, number: 0, volume: 0, title: "Placeholder Title", language: "en_US", date: .now, webUrl: nil, thumbnail: nil)
    }


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


extension DSKCommon.Chapter {
    var orderKey: Double {
        ThreadSafeChapter.orderKey(volume: volume, number: number)
    }
}


extension STTHelpers {
    static func filterChapters<T: STTChapterObject>(_ data: [T], with id: String) -> [T] {
        let languages = Preferences.standard.globalContentLanguages
        let blacklisted = STTHelpers.getBlacklistedProviders(for: id)
        
        var base = data
        // By Language
        if !languages.isEmpty {
            func lang(_ chapter: T) -> Bool {
                languages.contains(where: { $0
                    .lowercased()
                    .starts(with: chapter.language.lowercased()) })
            }
            base = base
                .filter(lang(_:))
        }
        
        // By Provider
        if !blacklisted.isEmpty {
            func provider(_ chapter: T) -> Bool {
                let providers = chapter.providers?.map(\.id) ?? []
                if providers.isEmpty { return true }
                return providers.allSatisfy({ !blacklisted.contains($0) })
            }
            base = base
                .filter(provider(_:))
        }
        
        return base
    }
}

extension STTHelpers {
    static func getBlacklistedProviders(for id: String) -> [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: STTKeys.BlackListedProviders(id)) ?? []
    }
    
    static func setBlackListedProviders(for id: String, values: [String]) {
        let values = Array(Set(values))
        UserDefaults.standard.setValue(values, forKey: STTKeys.BlackListedProviders(id))
    }
}
