//
//  Backup+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-31.
//

import Foundation

extension StoredOPDSServer : Codable {
    enum Keys: String, CodingKey {
        case id, alias, host, userName
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(alias, forKey: .alias)
        try container.encode(host, forKey: .host)
        try container.encode(userName, forKey: .userName)
    }
}
