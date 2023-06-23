//
//  Backup+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension StoredChapter: Codable {
    enum CodingKeys: String, CodingKey {
        case id, sourceId, contentId, chapterId
        case index, sourceIndex, number, volume, title, language, date
        case openInSafari, openAsNovel, webUrl
        case providers
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
//        sourceId = try container.decode(String.self, forKey: .sourceId)
//        contentId = try container.decode(String.self, forKey: .contentId)
        chapterId = try container.decode(String.self, forKey: .chapterId)
        index = try (container.decodeIfPresent(Int.self, forKey: .sourceIndex) ?? container.decode(Int.self, forKey: .index))
        number = try container.decode(Double.self, forKey: .number)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)

        title = try container.decodeIfPresent(String.self, forKey: .title)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        date = try container.decode(Date.self, forKey: .date)
        webUrl = try container.decodeIfPresent(String.self, forKey: .webUrl)
        providers = try container.decodeIfPresent(List<ChapterProvider>.self, forKey: .providers) ?? List<ChapterProvider>() // Schema 6 Addition
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
//        try container.encode(sourceId, forKey: .sourceId)
//        try container.encode(contentId, forKey: .contentId)
        try container.encode(chapterId, forKey: .chapterId)

        try container.encode(index, forKey: .index)
        try container.encode(number, forKey: .number)
        try container.encode(volume, forKey: .volume)
        try container.encode(title, forKey: .title)
        try container.encode(language, forKey: .language)
        try container.encode(date, forKey: .date)
        try container.encode(webUrl, forKey: .webUrl)
        try container.encode(providers, forKey: .providers)
    }
}

extension ChapterProvider: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, links
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        links = try container.decode(List<ChapterProviderLink>.self, forKey: .links)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(links, forKey: .links)
    }
}

extension ChapterProviderLink: Codable {
    enum CodingKeys: String, CodingKey {
        case url, type
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        type = try container.decode(DSKCommon.ChapterProviderType.self, forKey: .type)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(type, forKey: .type)
    }
}
