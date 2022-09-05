//
//  AL+Intercepter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Alamofire
import Foundation
import KeychainSwift

extension Anilist {
    class NetworkInterceptor: RequestInterceptor {
        func adapt(_ urlRequest: URLRequest, for _: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            var request = urlRequest

            // Anilist Access Token
            let keychain = KeychainSwift()
            keychain.synchronizable = true
            if let accessToken = keychain.get(STTKeys.anilistAccessToken) {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }

            completion(.success(request))
        }
    }
}
