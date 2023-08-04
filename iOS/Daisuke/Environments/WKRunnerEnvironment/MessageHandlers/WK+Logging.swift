//
//  WK+Logging.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import WebKit

struct WKHandler {}


extension WKHandler {
    class LogHandler: NSObject, WKScriptMessageHandler {
        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            let message = message.body as? [String: String]
            guard let message, let level = Logger.Level(rawValue: message["level"] ?? "LOG"), let msg = message["message"], let context = message["context"] else {
                return
            }
            Logger.shared.log(level: level, msg, context)
        }
    }
}
