//
//  WK+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Alamofire
import Foundation
import WebKit

extension WKHandler {
    class NetworkHandler: NSObject, WKScriptMessageHandlerWithReply {
        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
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
                return (nil, "\(error.localizedDescription)")
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
        try await DSKNetworkClient.shared.makeRequest(with: request)
    }
}
