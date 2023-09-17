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

struct ThreadSafeChapter: Hashable, Identifiable, STTChapterObject, Sendable {
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

    static func placeholders(count: Int) -> [Self] {
        (0 ... count).map { v in
            .init(id: v.description, sourceId: "", chapterId: "", contentId: "", index: 0, number: 0, volume: 0, title: "Placeholder Title", language: "en_US", date: .now, webUrl: nil, thumbnail: nil)
        }
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
        let d = inferredVolume * 10000
        return d + number
    }

    static func vnPair(from key: Double) -> (Double?, Double) {
        let inferredVolume = floor(key / 10000)
        let number = key.truncatingRemainder(dividingBy: 10000)

        let volume: Double? = inferredVolume == 999 ? nil : inferredVolume

        return (volume, number)
    }

    static func orderKey(volume: Double?, number: Double) -> Double {
        let d = (volume ?? 99) * 10000
        return d + number
    }
}

extension DSKCommon.Chapter {
    var orderKey: Double {
        ThreadSafeChapter.orderKey(volume: volume, number: number)
    }
}

extension STTHelpers {
    static func filterChapters<T: STTChapterObject>(_ data: [T], with id: String, callback: ((T) -> Void)? = nil) -> [T] {
        let languages = Preferences.standard.globalContentLanguages
        let blacklisted = STTHelpers.getBlacklistedProviders(for: id)
        var prepared: [T] = []
        
        
        func isLanguageCleared(_ chapter: T) -> Bool {
            guard !languages.isEmpty, chapter.language.uppercased() != "UNIVERSAL" else { return true }
            let value = languages.contains { base in
                let chapterLanguage = chapter.language.lowercased().replacingOccurrences(of: "_", with: "-").trimmingCharacters(in:.whitespacesAndNewlines).components(separatedBy: "-")
                let appLanguage = base.lowercased().replacingOccurrences(of: "_", with: "-").components(separatedBy: "-")
                
                
                let chapterLanguageCode = chapterLanguage.first
                let appLanguageCode = appLanguage.first
                                    
                guard let chapterLanguageCode, let appLanguageCode, appLanguageCode == chapterLanguageCode else {
                    return false
                }
                
                let appRegionCode = appLanguage.getOrNil(1)
                let chapterRegionCode = chapterLanguage.getOrNil(1)
                
                guard let appRegionCode, let chapterRegionCode else {
                    return true
                }
                
                return appRegionCode == chapterRegionCode
                
            }
            
            return value
        }
        
        func isBlackListCleared(_ chapter: T) -> Bool {
            guard !blacklisted.isEmpty,
                  let providers = chapter.providers?.map(\.id),
                  !providers.isEmpty else { return true }
            return providers.allSatisfy { !blacklisted.contains($0) }
        }
        
        
        for chapter in data {
            guard isBlackListCleared(chapter), isLanguageCleared(chapter) else { continue }
            prepared.append(chapter)
            callback?(chapter)
        }
        
        return prepared
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
