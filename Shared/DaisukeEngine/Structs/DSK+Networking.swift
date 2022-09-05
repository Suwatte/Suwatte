//
//  DSK+Networking.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-14.
//

import Alamofire
import AnyCodable
import Foundation

// MARK: Reqeust

extension DSKCommon {
    typealias CodableDict = [String: AnyCodable]
    struct Request: Codable, Hashable, Parsable {
        var url: String
        var method: String?
        var params: CodableDict?
        var body: CodableDict?
        var headers: [String: String]?
        var cookies: [String: String]?
        var timeout: Double?
        var maxRetries: Int?
    }

    struct RequestConfig: Codable, Parsable {
        var params: CodableDict?
        var body: CodableDict?
        var headers: [String: String]?
        var cookies: [String: String]?
        var timeout: Double?
        var maxRetries: Int?

        func toRequest(with url: String, method: HTTPMethod) -> Request {
            .init(url: url, method: method.rawValue, params: params, body: body, headers: headers, cookies: cookies, timeout: timeout, maxRetries: maxRetries)
        }
    }
}

// MARK: Response

extension DSKCommon {
    struct Response: Codable, Parsable {
        var data: String
        var status: Int
        var headers: [String: String]
        var request: Request
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
        guard let url = URL(string: url) else {
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

        return request
    }
}
