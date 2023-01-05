//
//  DSK+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Alamofire
import AnyCodable
import Foundation
import JavaScriptCore
import WebKit

@objc protocol DaisukeNetworkClientProtocol: JSExport, JSObjectProtocol {
    @objc(request:)
    func _request(_ request: JSValue) -> JSValue

    @objc(get::)
    func _get(_ url: JSValue, config: JSValue?) -> JSValue

    @objc(post::)
    func _post(_ url: JSValue, config: JSValue?) -> JSValue

    var requestInterceptHandler: JSValue? { get set }
    var responseInterceptHandler: JSValue? { get set }
}

extension DaisukeEngine {
    @objc class NetworkClient: JSObject, DaisukeNetworkClientProtocol {
        lazy var session: Alamofire.Session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(Preferences.standard.userAgent))
            return .init(configuration: configuration)
        }()
        typealias Request = DSKCommon.Request
        typealias Response = DSKCommon.Response
        typealias RequestConfig = DSKCommon.RequestConfig
        var requestInterceptHandler: JSValue?
        var responseInterceptHandler: JSValue?
        

        func _request(_ request: JSValue) -> JSValue {
            .init(newPromiseIn: request.context) { [self] resolve, reject in
                Task {
                    do {
                        let request = try Request(value: request)
                        let response = try await self.makeRequest(with: request)
                        let dict = try response.asDictionary()
                        resolve?.call(withArguments: [dict])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
                    session.session.configuration.timeoutIntervalForResource = 30
                }
            }
        }

        func _get(_ url: JSValue, config: JSValue?) -> JSValue {
            .init(newPromiseIn: url.context) { [self] resolve, reject in

                Task {
                    do {
                        let url = url.toString() ?? ""
                        var request: Request?
                        if let config = config, config.isObject {
                            let c = try RequestConfig(value: config)
                            request = c.toRequest(with: url, method: .get)
                        } else {
                            request = Request(url: url, method: "GET")
                        }
                        guard let request = request else {
                            reject?.call(withArguments: [DSK.Errors.NetworkErrorFailedToConvertRequestObject])
                            return
                        }
                        let response = try await self.makeRequest(with: request)
                        let dict = try response.asDictionary()
                        resolve?.call(withArguments: [dict])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
                }
            }
        }

        func _post(_ url: JSValue, config: JSValue?) -> JSValue {
            .init(newPromiseIn: url.context) { [self] resolve, reject in
                Task {
                    do {
                        let url = url.toString() ?? ""
                        var request: Request?

                        if let config = config, config.isObject {
                            let c = try RequestConfig(value: config)
                            request = c.toRequest(with: url, method: .post)
                        } else {
                            request = Request(url: url, method: "POST")
                        }

                        guard let request = request else {
                            reject?.call(withArguments: [DSK.Errors.NetworkErrorFailedToConvertRequestObject])
                            return
                        }

                        let response = try await self.makeRequest(with: request)
                        let dict = try response.asDictionary()
                        // TODO: Intercept Response
                        resolve?.call(withArguments: [dict])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
                }
            }
        }
    }
}

extension DaisukeEngine.NetworkClient {
    func makeRequest(with request: DSKCommon.Request) async throws -> Response {
        let request = try await handleRequestIntercept(request: request)
        let urlRequest = try request.toURLRequest()
        let afResponse = await session.request(urlRequest)
            .validate()
            .serializingString()
            .response
        session.session.configuration.timeoutIntervalForResource = request.timeout ?? 30
        guard let httpResponse = afResponse.response else {
            throw DaisukeEngine.Errors.NamedError(name: "Network Client", message: "Recieved Empty Response")
        }

        let data = try afResponse.result.get()
        var response = Response(data: data,
                                status: httpResponse.statusCode,
                                headers: httpResponse.headers.dictionary,
                                request: request)

        response = try await handleResponseIntercept(response: response)
        return response
    }
}

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
            let isURLEncoded = self.headers["content-type"]?.contains("x-www-form-urlencoded") ?? false

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

extension DaisukeEngine.NetworkClient {
    func handleRequestIntercept(request: Request) async throws -> Request {
        let handler = requestInterceptHandler
        guard let handler = handler else {
            return request
        }
        let dict = try! request.asDictionary()
        return try await withCheckedThrowingContinuation { continuation in
            handler.daisukeCall(arguments: [dict]) { value in
                let request = try Request(value: value)
                continuation.resume(returning: request)
            } onFailure: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    func handleResponseIntercept(response: Response) async throws -> Response {
        let handler = responseInterceptHandler
        guard let handler = handler else {
            return response
        }
        let dict = try! response.asDictionary()
        return try await withCheckedThrowingContinuation { continuation in
            handler.daisukeCall(arguments: [dict]) { value in
                let response = try Response(value: value)
                continuation.resume(returning: response)
            } onFailure: { error in
                continuation.resume(throwing: error)
            }
        }
    }
}

extension URL {
    func absoluteStringByTrimmingQuery() -> String? {
        if var urlcomponents = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            urlcomponents.query = nil
            return urlcomponents.string
        }
        return nil
    }
}
