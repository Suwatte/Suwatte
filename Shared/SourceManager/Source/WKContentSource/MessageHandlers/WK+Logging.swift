//
//  WK+Logging.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//

import Foundation
import WebKit

extension WKContentSource {
    class LogHandler: NSObject, WKScriptMessageHandler {
        internal let id: String
        init(id: String) {
            self.id = id
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            let message = message.body as? [String: String]
            guard let message, let level = Logger.Level(rawValue: message["level"] ?? "LOG"), let msg = message["message"], let context = message["context"] else {
                return
            }
            Logger.shared.log(level: level, msg, context)
        }
    }
}
