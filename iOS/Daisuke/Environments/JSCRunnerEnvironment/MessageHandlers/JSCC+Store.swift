//
//  JSCC+Store.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation
import JavaScriptCore

@objc protocol JSCHandlerProtocol: JSExport, JSObjectProtocol {
    @objc(post:)
    func _post(_ message: JSValue) -> JSValue
}

struct JSCHandler {}
extension JSCHandler {
    @objc class StoreHandler: JSObject, JSCHandlerProtocol {
        func _post(_ message: JSValue) -> JSValue {
            .init(newPromiseIn: message.context) { resolve, reject in
                let context = message.context

                Task {
                    do {
                        let message = try Message(value: message)
                        let response = try await self.handle(message: message)
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
}

private typealias H = JSCHandler.StoreHandler

extension H {
    struct Message: Parsable {
        var store: Store
        var action: Action
        var key: String
        var value: String?
        var id: String

        enum Action: String, Codable {
            case get, set, remove
        }

        enum Store: String, Codable {
            case os, ss
        }
    }
}

extension H {
    func handle(message: Message) async throws -> String? {
        let id = message.id
        let key = "\(id)|\(message.key)"
        let actor = await RealmActor.shared()
        switch message.store {
        case .os: // ObjectStore
            switch message.action {
            case .get:
                return await actor.getStoreValue(for: key)
            case .set:
                guard let value = message.value else {
                    throw DSK.Errors.ValueStoreErrorKeyValuePairInvalid
                }
                await actor.setStoreValue(for: key, value: value)
            case .remove:
                await actor.removeStoreValue(for: key)
            }
        case .ss: // SecureStore
            switch message.action {
            case .get:
                return await actor.getKeychainValue(for: id, key: message.key)
            case .set:
                guard let value = message.value else {
                    throw DSK.Errors.ValueStoreErrorKeyValuePairInvalid
                }
                await actor.setKeychainValue(for: id, key: message.key, value: value)
            case .remove:
                await actor.deleteKeyChainValue(for: id, key: message.key)
            }
        }
        return nil
    }
}
