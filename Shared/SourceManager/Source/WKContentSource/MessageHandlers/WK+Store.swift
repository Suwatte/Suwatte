//
//  WK+Store.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-26.
//

import WebKit


extension WKContentSource {
    class StoreHandler: NSObject, WKScriptMessageHandlerWithReply {
        internal let id: String
        
        init(id: String) {
            self.id = id
        }
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping (Any?, String?) -> Void
        ) {
            let body = message.body
            // Check JSON Validity
            let isValidJSON = JSONSerialization.isValidJSONObject(body)
            guard isValidJSON else {
                replyHandler(nil, DSK.Errors.InvalidJSONObject.localizedDescription)
                return
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: body)
                let message = try JSONDecoder().decode(Message.self, from: data)
                let value = try handle(message: message)
                replyHandler(value, nil)
            } catch {
                replyHandler(nil, error.localizedDescription)
            }
        }
    }
}

fileprivate typealias H = WKContentSource.StoreHandler

extension H {
    struct Message: Decodable {
        var store: Store
        var action: Action
        var key: String
        var value: String?
        
        enum Action : String, Decodable {
            case get, set , remove
        }
        
        enum Store: String, Decodable {
            case os, ss
        }
    }
}


extension H {
    func handle(message: Message) throws -> String? {
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
                        break
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
                        break
                    case .remove:
                        DataManager.shared.deleteKeyChainValue(for: id, key: message.key)
                }
                
        }
        return nil
    }
}
