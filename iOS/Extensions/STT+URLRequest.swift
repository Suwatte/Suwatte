//
//  STT+URLRequest.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-04-01.
//

import AnyCodable
import Foundation

extension URLRequest {
    func toDaisukeNetworkRequest() throws -> DSKCommon.Request {
        let url = self.url

        guard let url = url, let components = URLComponents(string: url.absoluteString) else {
            throw DSK.Errors.NamedError(name: "URLRequest Conversion", message: "URL is nil")
        }

        let baseURL = url.absoluteStringByTrimmingQuery() ?? url.absoluteString
        let method = self.method?.rawValue ?? ""
        let headers = self.headers.dictionary
        var body: [String: AnyCodable]?
        if let data = httpBody {
            let contentTypeHeader = self.headers["content-type"] ?? self.headers["Content-Type"]
            let isURLEncoded = contentTypeHeader?.contains("x-www-form-urlencoded") ?? false

            if isURLEncoded {
                let query = String(data: data, encoding: .utf8) ?? ""
                let url = URL(string: "https://suwatte.com/?\(query)")
                if let url = url, let components = URLComponents(string: url.absoluteString) {
                    body = parseQueryParam(components: components)
                }
            } else {
                body = try? JSONDecoder().decode(DSKCommon.CodableDict.self, from: data)
            }
        }
        let params = parseQueryParam(components: components)
        let request = DSKCommon.Request(url: baseURL, method: method, params: params, body: body, headers: headers, cookies: nil, timeout: timeoutInterval, maxRetries: nil)
        return request
    }

    func parseQueryParam(components: URLComponents) -> [String: AnyCodable] {
        let out: [String: AnyCodable] = [:]
        if let items = components.queryItems {
            var out: [String: AnyCodable] = [:]
            let dict = Dictionary(grouping: items, by: { $0.name })
            dict.forEach { key, values in
                if values.isEmpty {
                    return
                }
                if values.count == 1 {
                    if let value = values.first?.value {
                        out[key] = AnyCodable(stringLiteral: value)
                    }
                    return
                }
                let properKey = key.replacingOccurrences(of: "[]", with: "")
                out[properKey] = AnyCodable(values.compactMap { $0.value })
            }
        }

        return out
    }
}
