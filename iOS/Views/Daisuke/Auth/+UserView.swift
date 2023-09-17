//
//  +UserView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import SwiftUI

extension DSKAuthView {
    struct UserView: View {
        @EnvironmentObject var model: ViewModel
        var user: DSKCommon.User
        var runner: AnyRunner {
            model.runner
        }

        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        @State var presentWebView = false
        var body: some View {
            VStack(alignment: .leading) {
                // Header
                HStack(alignment: .center) {
                    BaseImageView(url: URL(string: user.avatar ?? ""))
                        .background(.gray)
                        .clipShape(Circle())
                        .frame(width: 75, height: 75)
                        .padding(.all, 7)

                    Text(user.name)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Group {
                    if let info = user.info {
                        InteractiveTagView(info) { tag in
                            Text(tag)
                                .modifier(ProfileTagStyle())
                        }
                    }
                }

                // Sign Out
                Group {
                    if method != .webview {
                        Button("Sign Out", role: .destructive) { handleSignOut() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    } else {
                        Button("Open WebView") { presentWebView.toggle() }
                            .buttonStyle(.bordered)
                    }
                }
                .fullScreenCover(isPresented: $presentWebView, onDismiss: model.reload) {
                    SmartNavigationView {
                        WebViewAuthView.WebViewRepresentable(isSignIn: false)
                            .navigationBarTitle("Sign Out", displayMode: .inline)
                            .closeButton(title: "Done")
                            .toast()
                            .tint(accentColor)
                            .accentColor(accentColor)
                    }
                }
                // Sync
                Group {
                    if let source = runner as? AnyContentSource, source.intents.librarySyncHandler {
                        DSKAuthView.LibrarySyncView(source: source)
                    }
                }
            }
        }

        var method: RunnerIntents.AuthenticationMethod {
            model.runner.intents.authenticationMethod
        }

        func handleSignOut() {
            Task {
                do {
                    try await runner.handleUserSignOut()
                } catch {
                    Logger.shared.error(error)
                    StateManager.shared.alert(title: "failed to sign out", message: "\(error.localizedDescription)")
                }
                model.reload()
            }
        }
    }
}
