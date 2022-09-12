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
        var session: Alamofire.Session = .default

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

                        // TODO: Intercept Response
                        resolve?.call(withArguments: [dict])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
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

                        // TODO: Intercept Response
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
        // Init Interceptor
        let intercepter = NetworkRequstIntercepter()
        intercepter.handler = requestInterceptHandler

        // TODO: Cookies
        //            let cookies = request.cookies?.compactMap { $0.toHTTPCookie() } ?? []
        //            cookies.forEach { cookie in
        //                self.session.sessionConfiguration.httpCookieStorage?.setCookie(cookie)
        //            }

        let urlRequest = try request.toURLRequest()

        let afResponse = await session.request(urlRequest, interceptor: intercepter)
            .validate()
            .serializingString()
            .response

        guard let httpResponse = afResponse.response, let httpRequest = afResponse.request else {
            throw DaisukeEngine.Errors.NamedError(name: "NWTK_CLT", message: "Recieved Empty Response")
        }
        let request = try httpRequest.toDaisukeNetworkRequest()
        let data = try afResponse.result.get()
        let response = Response(data: data,
                                status: httpResponse.statusCode,
                                headers: httpResponse.headers.dictionary,
                                request: request)

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
            body = try JSONDecoder().decode(DSKCommon.CodableDict.self, from: data)
        }
        var params: [String: AnyCodable]?

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
            params = out
        }
        let request = DSKCommon.Request(url: baseURL, method: method, params: params, body: body, headers: headers, cookies: nil, timeout: timeoutInterval, maxRetries: nil)
        return request
    }
}

extension DaisukeEngine.NetworkClient {
    class NetworkRequstIntercepter: RequestInterceptor {
        var handler: JSValue?
        func adapt(_ urlRequest: URLRequest, using _: RequestAdapterState, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            guard let handler = handler else {
                completion(.success(urlRequest))
                return
            }

            do {
                let request = try urlRequest.toDaisukeNetworkRequest()
                let dict = try request.asDictionary()
                handler.daisukeCall(arguments: [dict]) { value in
                    let request = try Request(value: value)
                    let urlRequest = try request.toURLRequest()
                    completion(.success(urlRequest))
                } onFailure: { error in
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
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
