//
//  STT+Encodable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import AnyCodable
import Foundation

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }

    func asAnyCodableDict() throws -> [String: AnyCodable] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: AnyCodable] else {
            throw NSError()
        }
        return dictionary
    }
}
