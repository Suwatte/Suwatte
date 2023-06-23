//
//  JSCC+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-31.
//

import Alamofire
import Foundation
import JavaScriptCore

extension JSCC {
    @objc class NetworkHandler: JSObject, JSCCHandlerProtocol {
        lazy var session: Alamofire.Session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.headers.add(.userAgent(Preferences.standard.userAgent))
            return .init(configuration: configuration)
        }()

        func _post(_ message: JSValue) -> JSValue {
            .init(newPromiseIn: message.context) { resolve, reject in
                Task {
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

private typealias H = JSCC.NetworkHandler

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
        guard let httpResponse = afResponse.response else {
            throw DaisukeEngine.Errors.NamedError(name: "Network Client", message: "Recieved Empty Response")
        }
        let data = try afResponse.result.get()
        let headers = httpResponse.headers.dictionary
        let response = DSKCommon.Response(data: data,
                                          status: httpResponse.statusCode,
                                          headers: headers)
        return response
    }
}
