//
//  DSK+Networking.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-14.
//

import Alamofire
import AnyCodable
import Foundation
import SwiftyJSON

// MARK: Reqeust

extension DSKCommon {
    typealias CodableDict = [String: AnyCodable]
    struct Request: Codable, Parsable {
        var url: String
        var method: String?
        var params: CodableDict?
        var body: SwiftyJSON.JSON?
        var headers: [String: String]?
        var cookies: [Cookie]?
        var timeout: Double?
        var maxRetries: Int?
        var maxRedirects: Int?
    }

    struct Cookie: Codable, Parsable, Hashable {
        var name: String
        var value: String

        func toHTTPCookie(with domain: String) -> HTTPCookie? {
            .init(properties: [.name: name, .domain: domain, .value: value, .path: "/"])
        }
    }

    struct RequestConfig: Codable, Parsable {
        var params: CodableDict?
        var body: SwiftyJSON.JSON?
        var headers: [String: String]?
        var cookies: [Cookie]?
        var timeout: Double?
        var maxRetries: Int?

        func toRequest(with url: String, method: HTTPMethod) -> Request {
            .init(url: url, method: method.rawValue, params: params, body: body, headers: headers, cookies: cookies, timeout: timeout, maxRetries: maxRetries)
        }
    }

    struct BasicURL: Parsable {
        var url: String
        var params: CodableDict?

        func toURL() throws -> URL {
            guard let url = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                Logger.shared.error("Invalid URL: \(url)")
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            var request = URLRequest(url: url)

            // Params
            if let p = params {
                let params = try p.asDictionary()
                request = try URLEncoding(destination: .queryString).encode(request, with: params)
            }

            guard let out = request.url else {
                Logger.shared.error("Invalid URL: \(request), \(url)")
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            return out
        }
    }
}

// MARK: Response

extension DSKCommon {
    struct Response: Codable, Parsable {
        var data: String
        var status: Int
        var headers: [String: String]
    }
}

// MARK: Helpers

extension DSKCommon.Request {
    var httpMethod: HTTPMethod {
        if let method = method {
            return .init(rawValue: method)
        } else {
            return .get
        }
    }
}

extension DSKCommon.Request {
    func toURLRequest() throws -> URLRequest {
        guard let url = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)), let host = url.host else {
            Logger.shared.error("Invalid URL: \(url)")
            throw DSK.Errors.NetworkErrorInvalidRequestURL
        }

        var mappedHeaders: HTTPHeaders?
        if let headers = headers {
            mappedHeaders = .init(headers.map { HTTPHeader(name: $0.key, value: $0.value) })
        }
        var request = try URLRequest(url: url, method: httpMethod, headers: mappedHeaders)

        // Params
        if let p = params {
            let params = try p.asDictionary()
            request = try URLEncoding(destination: .queryString).encode(request, with: params)
        }

        // Body
        let isURLEncoded = headers?["content-type"]?.contains("x-www-form-urlencoded") ?? false

        if isURLEncoded {
            let parsedBody = try body?.asDictionary()
            request = try URLEncoding(destination: .httpBody).encode(request, with: parsedBody)
        } else {
            if let body = body {
                request.httpBody = try JSONEncoder().encode(body)
            }
        }

        // Cookies
        if let cookies {
            let jar = HTTPCookieStorage.shared
            cookies.compactMap { $0.toHTTPCookie(with: host) }.forEach {
                jar.setCookie($0)
            }
        }

        return request
    }
}
