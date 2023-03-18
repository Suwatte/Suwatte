//
//  JSCC+Logging.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation
import JavaScriptCore

extension JSCC {
    @objc class LogHandler: JSObject, JSCCHandlerProtocol {
        func _post(_ message: JSValue) -> JSValue {
            let output = JSValue(nullIn: message.context)!
            let message = message.toDictionary() as? [String: String]
            
            guard let message else {
                Logger.shared.error("Failed to Convert Handler Message")
                return output
            }
            log( message: message)
            return output
        }
    }
}


extension JSCC.LogHandler {
    internal func log( message: [String: String]) {
        guard let level = Logger.Level(rawValue: message["level"] ?? "LOG"), let msg = message["message"], let context = message["context"] else {
            Logger.shared.log("\(message)")
            return
        }
        Logger.shared.log(level: level, msg, context)
    }
}
