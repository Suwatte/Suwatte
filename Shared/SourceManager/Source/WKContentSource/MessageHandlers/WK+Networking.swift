//
//  WK+Networking.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-25.
//

import WebKit

extension WKContentSource {
    class NetworkHandler: NSObject, WKScriptMessageHandlerWithReply {
        internal let id: String
        let client = DSK.NetworkClient()

        init(id: String) {
            self.id = id
        }

        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping (Any?, String?) -> Void
        ) {
            let body = message.body
            Task {
                do {
                    let response = try await request(body)
                    replyHandler(response, nil)
                } catch {
                    replyHandler(nil, error.localizedDescription)
                }
            }
        }
    }
}

private typealias H = WKContentSource.NetworkHandler

extension H {
    func request(_ config: Any) async throws -> Any {
        // Check JSON Validity
        let isValidJSON = JSONSerialization.isValidJSONObject(config)
        guard isValidJSON else {
            throw DSK.Errors.InvalidJSONObject
        }
        // Get Data
        let data = try JSONSerialization.data(withJSONObject: config)
        let object = try JSONDecoder().decode(DSKCommon.Request.self, from: data)

        // Make Request
        let response = try await client.makeRequest(with: object)

        // Serialize Response
        let encodedResponse = try JSONEncoder().encode(response)
        let responseObject = try JSONSerialization.jsonObject(with: encodedResponse)
        return responseObject
    }
}
