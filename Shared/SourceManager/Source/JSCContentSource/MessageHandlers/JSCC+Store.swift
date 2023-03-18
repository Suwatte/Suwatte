//
//  JSCC+Store.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation
import JavaScriptCore


@objc protocol JSCCHandlerProtocol: JSExport, JSObjectProtocol {
    @objc(post:)
    func _post(_ message: JSValue) -> JSValue
}

extension JSCC {
    @objc class StoreHandler: JSObject, JSCCHandlerProtocol {
        func _post(_ message: JSValue) -> JSValue {
            .init(newPromiseIn: message.context) { resolve, reject in
                let context = message.context
                do {
                    let message = try Message(value: message)
                    let response = try self.handle(message: message)
                    if let response {
                        resolve?.call(withArguments: [response])
                    } else {
                        let jsNull = JSValue(nullIn: context)
                        resolve?.call(withArguments: [jsNull as Any])
                    }
                } catch {
                    reject?.call(withArguments: [error])
                }
            }
        }
    }
}


private typealias H = JSCC.StoreHandler

extension H {
    struct Message: Parsable {
        var store: Store
        var action: Action
        var key: String
        var value: String?

        enum Action: String, Codable {
            case get, set, remove
        }

        enum Store: String, Codable {
            case os, ss
        }
    }
}

extension H {
    func handle(message: Message) throws -> String? {
        let id = try self.getRunnerID()
        switch message.store {
        case .os: // ObjectStore
            switch message.action {
            case .get:
                return DataManager.shared.getStoreValue(for: id, key: message.key)
            case .set:
                guard let value = message.value else {
                    throw DSK.Errors.ValueStoreErrorKeyValuePairInvalid
                }
                DataManager.shared.setStoreValue(for: id, key: message.key, value: value)
            case .remove:
                DataManager.shared.removeStoreValue(for: id, key: message.key)
            }

        case .ss: // SecureStore
            switch message.action {
            case .get:
                return DataManager.shared.getKeychainValue(for: id, key: message.key)
            case .set:
                guard let value = message.value else {
                    throw DSK.Errors.ValueStoreErrorKeyValuePairInvalid
                }
                DataManager.shared.setKeychainValue(for: id, key: message.key, value: value)
            case .remove:
                DataManager.shared.deleteKeyChainValue(for: id, key: message.key)
            }
        }
        return nil
    }
}
