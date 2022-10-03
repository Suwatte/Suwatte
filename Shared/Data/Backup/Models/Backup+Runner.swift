//
//  Backup+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-31.
//

import Foundation

extension StoredRunnerList: Codable {
    enum Keys: String, CodingKey {
        case listName, url
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        listName = try container.decodeIfPresent(String.self, forKey: .listName)
        url = try container.decode(String.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(listName, forKey: .listName)
        try container.encode(url, forKey: .url)
    }
}

extension StoredRunnerObject: Codable {
    enum Keys: String, CodingKey {
        case id, name, listURL, thumbnail, order
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        listURL = try container.decodeIfPresent(String.self, forKey: .listURL)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(listURL, forKey: .listURL)
        try container.encode(thumbnail, forKey: .thumbnail)
    }
}
