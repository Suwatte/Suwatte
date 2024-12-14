//
//  WKR+JS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import WebKit

extension WKRunner {
    func eval(_ str: String, _ args: [String: Any] = [:]) async throws {
        _ = try await wv.callAsyncJavaScript(str, arguments: args, contentWorld: .defaultClient)
    }

    func evalNullable<T: Decodable>(_ str: String, _ args: [String: Any] = [:]) async throws -> T? {
        let data = try await wv.callAsyncJavaScript(str, arguments: args, contentWorld: .defaultClient)
        return try await RunnerActor.run {
            let value = data as? String
            guard let value, let data = value.data(using: .utf8, allowLossyConversion: false) else {
                if value == nil { return nil }
                throw DSK.Errors.InvalidJSONObject
            }

            let output = try DaisukeEngine.decode(data: data, to: T.self)
            return output
        }
    }

    func eval<T: Decodable>(_ str: String, _ args: [String: Any] = [:]) async throws -> T {
        let data = try await wv.callAsyncJavaScript(str, arguments: args, contentWorld: .defaultClient)
        return try await RunnerActor.run {
            var value: String?
            if let result = data as? [String: AnyObject] {
                if let error = result["error"] {
                    throw DaisukeEngine.Errors.nativeWKError(for: error)
                }
                value = result["value"] as? String
            }

            if let result = data as? String {
                value = result
            }

            guard let value, let data = value.data(using: .utf8, allowLossyConversion: false) else {
                throw DSK.Errors.InvalidJSONObject
            }

            let output = try DaisukeEngine.decode(data: data, to: T.self)
            return output
        }
    }

    func script(_ value: String) -> String {
        """
        let result = {};
        try {
          \(value);
          result.value = JSON.stringify(data);
        } catch (error) {
          result.error = { ...error, message: error.message.toString() };
        }
        return result;
        """
    }
}
