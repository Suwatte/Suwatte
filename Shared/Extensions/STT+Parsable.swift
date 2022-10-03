//
//  STT+Parsable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-12.
//

import Foundation
import JavaScriptCore

protocol Parsable: Codable {
    init(value: JSValue) throws
}

extension Parsable {
    init(value: JSValue) throws {
        guard let str = DaisukeEngine.stringify(val: value) else {
            throw DaisukeEngine.Errors.NamedError(name: "Conversion Error", message: "Could not convert returned valeu to JSON string.")
        }

        let jsonData = str.data(using: .utf8)!
        self = try DaisukeEngine.decode(data: jsonData, to: Self.self)
    }
}

extension DaisukeEngine {
    static func stringify(val: JSValue) -> String? {
        let json = val.context.evaluateScript("(function(){ return JSON })()")
        return json?.invokeMethod("stringify", withArguments: [val]).toString()
    }

    static func decode<T: Decodable>(data: Data, to _: T.Type) throws -> T {
        let decoder = JSONDecoder()

        // Date Formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        // Decode & Closure
        let object = try decoder.decode(T.self, from: data)
        return object
    }

    static func encode<T: Encodable>(value: T) throws -> Data {
        let encoder = JSONEncoder()

        // Date Formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        encoder.dateEncodingStrategy = .formatted(dateFormatter)

        // Encode & Closure
        let data = try encoder.encode(value)
        return data
    }

    static func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter.string(from: date)
    }
}
