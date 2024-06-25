//
//  Backup+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

extension InteractorStoreObject : Codable {
    enum Keys: String, CodingKey {
        case id, interactorId, key, value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(interactorId, forKey: .interactorId)
        try container.encode(key, forKey: .key)
        try container.encode(value, forKey: .value)
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)

        id = try container.decode(String.self, forKey: .id)
        interactorId = try container.decode(String.self, forKey: .interactorId)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decode(String.self, forKey: .value)
    }
}
