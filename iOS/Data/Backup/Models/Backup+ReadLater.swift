//
//  Backup+ReadLater.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension ReadLater: Codable {
    enum Keys: String, CodingKey {
        case id, content, dateAdded
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        id = try container.decode(String.self, forKey: .id)
        content = try container.decodeIfPresent(StoredContent.self, forKey: .content)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(dateAdded, forKey: .dateAdded)
    }
}
