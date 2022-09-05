//
//  Backup+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension LibraryCollection: Codable {
    enum Keys: String, CodingKey {
        case id, name, order, filter
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(_id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(order, forKey: .order)
        try container.encode(filter, forKey: .filter)
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        _id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        order = try container.decode(Int.self, forKey: .order)
        filter = try container.decodeIfPresent(LibraryCollectionFilter.self, forKey: .filter)
    }
}

extension LibraryCollectionFilter: Codable {
    enum Keys: String, CodingKey {
        case adultContent, readingFlags, textContains, statuses, sources, tagContains, contentType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(adultContent, forKey: .adultContent)
        try container.encode(readingFlags, forKey: .readingFlags)
        try container.encode(textContains, forKey: .textContains)
        try container.encode(statuses, forKey: .statuses)
        try container.encode(tagContains, forKey: .tagContains)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(sources, forKey: .sources)
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: Keys.self)

        adultContent = try container.decode(ContentSelectionType.self, forKey: .adultContent)
        readingFlags = try container.decode(List<LibraryFlag>.self, forKey: .readingFlags)
        textContains = try container.decode(List<String>.self, forKey: .textContains)
        tagContains = try container.decode(List<String>.self, forKey: .tagContains)
        sources = try container.decode(List<String>.self, forKey: .sources)
        statuses = try container.decode(List<ContentStatus>.self, forKey: .statuses)
        contentType = try container.decode(List<ExternalContentType>.self, forKey: .contentType)
    }
}
