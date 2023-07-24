//
//  DRV+Auth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import RealmSwift
import SwiftUI

struct DSKAuthView: View {
    @StateObject var model: ViewModel

    var body: some View {
        LoadableView(model.load, model.loadable) { user in
            if let user {
                UserView(user: user)
            } else {
                AuthenticationGateway(runner: model.runner)
            }
        }
        .environmentObject(model)
    }
}

extension DSKAuthView {
    struct AuthenticationGateway: View {
        var runner: JSCRunner
        var method: RunnerIntents.AuthenticationMethod {
            runner.intents.authenticationMethod
        }

        var body: some View {
            Group {
                switch method {
                case .webview:
                    WebViewAuthView()
                case .basic:
                    BasicAuthView()
                case .oauth:
                    OAuthView()
                case .unknown:
                    Text("Authentication is improperly configured. Suwatte could not derive the authentication method your runner is using.")
                }
            }
        }
    }
}
