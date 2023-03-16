//
//  WK+ModifiableSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-14.
//

import Foundation


extension WKContentSource : ModifiableSource {
    func getCloudflareVerificationRequest() async throws -> DSKCommon.Request {
        let body = "return getCloudflareVerificationRequest();"
        return try await eval(body, to: DSKCommon.Request.self)
    }
    
    func willRequestImage(request: DSKCommon.Request) async throws -> DSKCommon.Request {
        let body = "return willRequestImage(request);"
        let arguments = ["request": try request.asDictionary()]
        return try await eval(body, arguments, to: DSKCommon.Request.self)
    }
}
