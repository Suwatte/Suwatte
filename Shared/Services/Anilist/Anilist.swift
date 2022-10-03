//
//  Anilist.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Alamofire
import AuthenticationServices
import Foundation
import KeychainSwift

class Anilist: NSObject, ObservableObject {
    static let shared = Anilist()

    @Published var notifier = false

    internal let session = Session(configuration: URLSessionConfiguration.af.default, interceptor: NetworkInterceptor(), eventMonitors: [])

    internal let baseURL = URL(string: "https://graphql.anilist.co")!
}

// MARK: Handle Token

extension Anilist {
    func deleteToken() {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.delete(STTKeys.anilistAccessToken)
    }

    static func signedIn() -> Bool {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        return keychain.get(STTKeys.anilistAccessToken) != nil
    }
}

extension Anilist: ASWebAuthenticationPresentationContextProviding {
    var oauthEndpoint: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "anilist.co"
        components.path = "/api/v2/oauth/authorize"
        components.queryItems =
            [
                "client_id": String(STTKeys.anilistClientId),
                "response_type": "token",
            ].map { URLQueryItem(name: $0, value: $1) }
        return components.url!
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

extension Anilist {
    func authenticate() {
        let redirect = URL(string: "STTKeys.anilistRedirectUrl")!
        let authSession = ASWebAuthenticationSession(
            url: oauthEndpoint, callbackURLScheme: redirect.absoluteString
        ) { url, error in
            if let _ = error {
            } else if let url = url {
                self.processResponseURL(url: url)
            }
        }

        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = true
        authSession.start()
    }

    func processResponseURL(url: URL) {
        let anilistComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let anilistFragment = anilistComponents?.fragment,
           let dummyURL = URL(string: "https://dummyurl.com?\(anilistFragment)"),
           let components = URLComponents(url: dummyURL, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems,
           let token = queryItems.filter({ $0.name == "access_token" }).first?.value
        {
            let keychain = KeychainSwift()
            keychain.synchronizable = true
            keychain.set(token, forKey: STTKeys.anilistAccessToken)
            notifier.toggle()
        }
    }
}
