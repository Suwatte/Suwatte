//
//  JSCC+ModifiableSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation

extension JSCC: ModifiableSource {
    func getCloudflareVerificationRequest() async throws -> DSKCommon.Request {
        try await callMethodReturningDecodable(method: "getCloudflareVerificationRequest", arguments: [], resolvesTo: DSKCommon.Request.self)
    }

    func willRequestImage(request: DSKCommon.Request) async throws -> DSKCommon.Request {
        guard methodExists(method: "willRequestImage") else {
            throw DSK.Errors.MethodNotImplemented
        }

        let request = try request.asDictionary()

        return try await callMethodReturningDecodable(method: "willRequestImage", arguments: [request], resolvesTo: DSKCommon.Request.self)
    }
}
