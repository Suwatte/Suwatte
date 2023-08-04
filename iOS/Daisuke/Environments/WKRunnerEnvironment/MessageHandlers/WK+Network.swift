//
//  WK+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import Alamofire
import WebKit


extension WKHandler {
    class NetworkHandler: NSObject, WKScriptMessageHandlerWithReply {
        lazy var session: Alamofire.Session = {
            let configuration = URLSessionConfiguration.af.default
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.headers.add(.userAgent(Preferences.standard.userAgent))
            return .init(configuration: configuration)
        }()
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
            
            let body = await MainActor.run {
                message.body
            }
            
            // Check JSON Validity
            let isValidJSON = JSONSerialization.isValidJSONObject(body)
            guard isValidJSON else {
                return (nil, DSK.Errors.InvalidJSONObject.localizedDescription)
            }
            
            do {
                let data = try JSONSerialization.data(withJSONObject: body)
                let message = try JSONDecoder().decode(Message.self, from: data)
                let value = try await handle(message: message).asDictionary()
                return (value, nil)
            } catch {
                return (nil, "\(error)")
            }
        }
    }
}



private typealias H = WKHandler.NetworkHandler

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

