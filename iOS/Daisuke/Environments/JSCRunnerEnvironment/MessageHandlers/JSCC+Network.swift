//
//  JSCC+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-31.
//

import Alamofire
import Foundation
import JavaScriptCore

extension JSCHandler {
    @objc class NetworkHandler: JSObject, JSCHandlerProtocol {
        lazy var session: Alamofire.Session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.headers.add(.userAgent(Preferences.standard.userAgent))
            return .init(configuration: configuration)
        }()

        func _post(_ message: JSValue) -> JSValue {
            .init(newPromiseIn: message.context) { resolve, reject in
                Task.detached {
                    do {
                        let message = try Message(value: message)
                        let response = try await self.handle(message: message)
                        let out = try response.asDictionary()
                        resolve?.call(withArguments: [out])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
                }
            }
        }
    }
}

private typealias H = JSCHandler.NetworkHandler

extension H {
    typealias Message = DSKCommon.Request
}

extension H {
    func handle(message: Message) async throws -> DSKCommon.Response {
        try await makeRequest(with: message)
    }

    func makeRequest(with request: Message) async throws -> DSKCommon.Response {
        let urlRequest = try request.toURLRequest()
        let afResponse = await session.request(urlRequest)
            .serializingString()
            .response
        session.session.configuration.timeoutIntervalForResource = request.timeout ?? 30
        
        // Serialized Response
        let data = try afResponse.result.get()
        
        // Get HTTP Response
        guard let httpResponse = afResponse.response else {
            throw DaisukeEngine.Errors.NamedError(name: "Network Client", message: "Did not recieve a response")
        }
        
        let headers = httpResponse.headers.dictionary
        let response = DSKCommon.Response(data: data,
                                          status: httpResponse.statusCode,
                                          headers: headers)
        return response
    }
}
