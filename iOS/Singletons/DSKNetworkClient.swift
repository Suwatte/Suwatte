//
//  DSKNetworkClient.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-17.
//

import Foundation
import Alamofire



final class DSKNetworkClient {
    static let shared = DSKNetworkClient()
    
    lazy var session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.headers.add(.userAgent(Preferences.standard.userAgent))
        return .init(configuration: configuration)
    }()
    
    func makeRequest(with request: DSKCommon.Request) async throws -> DSKCommon.Response {
        let urlRequest = try request.toURLRequest()
        let afResponse = await session.request(urlRequest)
            .serializingString(encoding: .utf8)
            .response
        session.session.configuration.timeoutIntervalForResource = request.timeout ?? 30

        // Serialized Response
        let data = try afResponse.result.get()

        // Get HTTP Response
        guard let httpResponse = afResponse.response else {
            throw DaisukeEngine.Errors.NamedError(name: "Network Client", message: "Did not recieve a response")
        }

        let headers = httpResponse.headers.dictionary
        let response = DSKCommon.Response(data: data,
                                          status: httpResponse.statusCode,
                                          headers: headers)
        return response
    }
    
}
