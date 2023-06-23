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
        let jsonData = str.data(using: .utf8, allowLossyConversion: false)!
        self = try DaisukeEngine.decode(data: jsonData, to: Self.self)
    }
}

extension DaisukeEngine {
    static func stringify(val: JSValue) -> String? {
        let json = val.context.evaluateScript("""
        (function () {
          return JSON;
        })();
        """)
        return json?.invokeMethod("stringify", withArguments: [val]).toString()
    }

    static func decode<T: Decodable>(data: Data, to _: T.Type, dateFormatter: DateFormatter? = nil) throws -> T {
        let decoder = JSONDecoder()

        // Date Formatter
        decoder.dateDecodingStrategy = dateFormatter != nil ? .formatted(dateFormatter!) : .iso8601
        // Decode & Closure
        let object = try decoder.decode(T.self, from: data)
        return object
    }

    static func encode<T: Encodable>(value: T) throws -> Data {
        let encoder = JSONEncoder()

        // Date Formatter
        encoder.dateEncodingStrategy = .iso8601

        // Encode & Closure
        let data = try encoder.encode(value)
        return data
    }

    static func stringify(_ v: Encodable) throws -> String {
        let data = try Self.encode(value: v)
        let str = String(data: data, encoding: .utf8)
        guard let str else {
            throw DSK.Errors.InvalidJSONObject
        }
        return str
    }

    static func parse<T: Decodable>(_ v: String, to _: T.Type) throws -> T {
        let data = v.data(using: .utf8)
        guard let data else {
            throw DSK.Errors.InvalidJSONObject
        }

        return try Self.decode(data: data, to: T.self)
    }
}
