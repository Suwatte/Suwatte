//
//  DSKNetworkClient.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-17.
//

import Alamofire
import Foundation

final class DSKNetworkClient {
    static let shared = DSKNetworkClient()
    private let session: Session

    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.headers.add(.userAgent(Preferences.standard.userAgent))
        session = .init(configuration: configuration)
    }

    func makeRequest(with request: DSKCommon.Request) async throws -> DSKCommon.Response {
        session.session.configuration.timeoutIntervalForResource = request.timeout ?? 30

        let urlRequest = try request.toURLRequest()
        let afResponse = await session.request(urlRequest)
            .serializingString(encoding: .utf8)
            .response

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
