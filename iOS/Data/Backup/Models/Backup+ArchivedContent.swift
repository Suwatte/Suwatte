//
//  Backup+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension ArchivedContent: Codable {
    enum Keys: String, CodingKey {
        case id, relativePath, name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(name, forKey: .name)
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        id = try container.decode(String.self, forKey: .id)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        name = try container.decode(String.self, forKey: .name)
    }
}
