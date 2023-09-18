//
//  JSCC+Network.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-31.
//

import Alamofire
import Foundation
import JavaScriptCore

extension JSCHandler {
    @objc class NetworkHandler: JSObject, JSCHandlerProtocol {
        func _post(_ message: JSValue) -> JSValue {
            .init(newPromiseIn: message.context) { resolve, reject in
                Task.detached {
                    do {
                        let message = try Message(value: message)
                        let response = try await self.handle(message: message)
                        let out = try response.asDictionary()
                        resolve?.call(withArguments: [out])
                    } catch {
                        reject?.call(withArguments: [error])
                    }
                }
            }
        }
    }
}

private typealias H = JSCHandler.NetworkHandler

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
