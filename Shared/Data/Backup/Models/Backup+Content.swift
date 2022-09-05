//
//  Backup+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension StoredContent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, sourceId, contentId, title, additionalTitles, covers, creators, status
        case originalLanuguage, summary, adultContent, url, properties, recommendedReadingMode, contentType
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        _id = try container.decode(String.self, forKey: .id)
        sourceId = try container.decode(String.self, forKey: .sourceId)
        contentId = try container.decode(String.self, forKey: .contentId)

        title = try container.decode(String.self, forKey: .title)
        additionalTitles = try container.decode(List<String>.self, forKey: .additionalTitles)
        covers = try container.decode(List<String>.self, forKey: .covers)
        creators = try container.decode(List<String>.self, forKey: .creators)
        status = try container.decode(ContentStatus.self, forKey: .status)

        summary = try container.decode(String.self, forKey: .summary)
        adultContent = try container.decode(Bool.self, forKey: .adultContent)
        url = try container.decode(String.self, forKey: .url)
        properties = try container.decode(List<StoredProperty>.self, forKey: .properties)
        recommendedReadingMode = try container.decodeIfPresent(ReadingMode.self, forKey: .recommendedReadingMode) ?? .PAGED_MANGA
        contentType = try container.decodeIfPresent(ExternalContentType.self, forKey: .contentType) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(_id, forKey: .id)
        try container.encode(sourceId, forKey: .sourceId)
        try container.encode(contentId, forKey: .contentId)
        try container.encode(title, forKey: .title)
        try container.encode(additionalTitles, forKey: .additionalTitles)
        try container.encode(covers, forKey: .covers)
        try container.encode(creators, forKey: .creators)
        try container.encode(status, forKey: .status)
        try container.encode(summary, forKey: .summary)
        try container.encode(adultContent, forKey: .adultContent)
        try container.encode(url, forKey: .url)
        try container.encode(properties, forKey: .properties)
        try container.encode(recommendedReadingMode, forKey: .recommendedReadingMode)
        try container.encode(contentType, forKey: .contentType)
    }
}

// MARK: Stored Tag

extension StoredTag: Codable {
    enum CodingKeys: String, CodingKey {
        case id, label, adultContent
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        adultContent = try container.decode(Bool.self, forKey: .adultContent)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(adultContent, forKey: .adultContent)
    }
}

// MARK: StoredProperty

extension StoredProperty: Codable {
    enum Keys: String, CodingKey {
        case label, tags
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        tags = try container.decode(List<StoredTag>.self, forKey: .tags)
        label = try container.decode(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(label, forKey: .label)
        try container.encode(tags, forKey: .tags)
    }
}
