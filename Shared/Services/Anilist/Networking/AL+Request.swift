//
//  AL+Request.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Alamofire
import Foundation

extension Anilist {
    typealias JSON = [String: Any]
    func request<T: Decodable>(query: String, variables: JSON = [:], to _: T.Type) async throws -> T {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            let parameters = ["query": query, "variables": variables] as JSON

            session.request(baseURL, method: .post, parameters: parameters, encoding: JSONEncoding.default).validate().responseData { response in

                switch response.result {
                case let .success(data):
                    do {
                        let decoder = JSONDecoder()
                        let out = try decoder.decode(T.self, from: data)
                        continuation.resume(returning: out)
                    } catch {
                        continuation.resume(throwing: error)
                    }

                case let .failure(error):
                    if error.responseCode == 401 {
                        self?.deleteToken()
                    }
                    print(error.localizedDescription)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
