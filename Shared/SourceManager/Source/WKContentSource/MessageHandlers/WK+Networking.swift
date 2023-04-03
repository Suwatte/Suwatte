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
        init(id: String) {
            self.id = id
        }

        func userContentController(
            _: WKUserContentController,
            didReceive _: WKScriptMessage,
            replyHandler _: @escaping (Any?, String?) -> Void
        ) {}
    }
}

private typealias H = WKContentSource.NetworkHandler

extension H {
    func request(_: Any) async throws -> Any {
        throw DSK.Errors.MethodNotImplemented
    }
}
