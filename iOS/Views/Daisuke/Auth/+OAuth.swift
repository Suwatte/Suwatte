//
//  +OAuth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import AuthenticationServices
import SwiftUI

extension DSKAuthView {
    struct OAuthView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            Button {
                Task {
                    call()
                }
            } label: {
                Label("Sign In", systemImage: "person.fill.viewfinder")
            }
            .buttonStyle(.plain)
        }

        func call() {
            Task {
                do {
                    try await handle()
                } catch {
                    Logger.shared.error(error)
                    alert()
                }
            }
        }

        func alert() {
            StateManager.shared.alert(title: "\(model.runner.name)", message: "Failed to Sign In to \(model.runner.name)")
        }

        func handle() async throws {
            let runner = model.runner

            let basicURL = try await runner.getOAuthRequestURL()
            let url = try basicURL.toURL()

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "suwatte") { callbackURL, error in
                if let error {
                    Logger.shared.error(error)
                    alert()
                    return
                }

                if let callbackURL {
                    Task {
                        await callback(callbackURL)
                    }
                    return
                }

                // No CB URL
                alert()
            }

            let anchor = WebAuthAnchor()
            session.presentationContextProvider = anchor
            session.start()
        }

        func callback(_ url: URL) async {
            do {
                try await model.runner.handleOAuthCallback(response: url.absoluteString)
                model.reload()
            } catch {
                Logger.shared.error(error)
                alert()
            }
        }
    }
}

final class WebAuthAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    @MainActor func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        getKeyWindow()!
    }
}
