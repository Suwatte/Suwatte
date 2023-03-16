//
//  DRV+Auth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Alamofire
import RealmSwift
import SwiftUI
import UIKit
import WebKit

extension ContentSourceView {
    struct AuthSection: View {
        var source: any AuthSource
        @State var presentBasicAuthSheet = false
        @State var presentWebView = false
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        var method: DSKCommon.AuthMethod? {
            source.config.authenticationMethod
        }

        @State var user: Loadable<DSKCommon.User> = .idle

        var body: some View {
            Group {
                Gateway
            }
            .sheet(isPresented: $presentBasicAuthSheet) {
                NavigationView {
                    SignInSheet(usesEmail: method == .email_pw)
                        .navigationTitle("Sign In")
                        .closeButton()
                        .tint(accentColor)
                        .accentColor(accentColor)
                }
            }
            .fullScreenCover(isPresented: $presentWebView) {
                NavigationView {
                    WebAuthWebView(source: source)
                        .navigationBarTitle("Authenticate In WebView", displayMode: .inline)
                        .closeButton(title: "Done")
                        .toast()
                        .tint(accentColor)
                        .accentColor(accentColor)
                }
            }
            .animation(.default, value: user)
        }

        var Gateway: some View {
            LoadableView(loadUser, user) {
                LoadedUserView(user: $0)
            }
        }

        func loadUser() {
            user = .loading
            Task {
                do {
                    let data = try await source.getAuthenticatedUser()
                    if let data {
                        self.user = .loaded(data)
                    }
                } catch {
                    self.user = .failed(error)
                }
            }
        }

        @ViewBuilder
        func LoadedUserView(user: DSKCommon.User) -> some View {
            AuthenticatedUserView(user: user, presentWebView: $presentWebView)
        }

        @ViewBuilder
        func LoadedNoUserView() -> some View {
            if let method {
                Section {
                    Button {
                        switch method {
                        case .email_pw, .username_pw:
                            presentBasicAuthSheet.toggle()
                        case .oauth:
                            break
                        case .web:
                            presentWebView.toggle()
                        }
                    } label: {
                        Label("Sign In", systemImage: "person.fill.viewfinder")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Authentication")
                }
            }
        }
    }
}

extension ContentSourceView {
    struct SignInSheet: View {
        var usesEmail: Bool
        @State var username: String = ""
        @State var password: String = ""
        @State var loginStatus: Loadable<Bool> = .idle
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var source: DaisukeEngine.LocalContentSource

        var body: some View {
            VStack {
                Image("stt_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 75, alignment: .center)
                    .clipShape(Circle())
                    .padding()
                Text("Sign In to \(source.name)")
                    .font(.title)
                    .fontWeight(.semibold)
                    .kerning(1.5)
                    .padding()

                EmailField
                PasswordField

                if loginStatus.error != nil {
                    AuthFailed
                        .padding(.horizontal)
                }
                LoginButton
                Spacer()
            }
            .frame(maxWidth: UIScreen.main.bounds.width)

            .padding()
        }

        // MARK: Views

        var EmailField: some View {
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.4))
                    .frame(width: 15, alignment: .center)
                TextField(usesEmail ? "Email" : "Username", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
            }
            .padding()
            .background(Color.primary.opacity(0.12))
            .cornerRadius(15)
            .padding(.horizontal)
        }

        var PasswordField: some View {
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.4))
                    .frame(width: 15, alignment: .center)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .padding()
            .background(Color.primary.opacity(0.12))
            .cornerRadius(15)
            .padding(.horizontal)
            .padding(.top)
        }

        var LoginButton: some View {
            Button {
                signIn()
            } label: {
                ZStack {
                    if loginStatus == .loading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                    }
                }

                .padding(.vertical)
                .frame(width: 250)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .disabled(!isValidInput || loginStatus == .loading)
            .padding(.top)
        }

        var AuthFailed: some View {
            HStack {
                Image(systemName: "exclamationmark.circle")
                Text("Failed to Sign In")
            }
            .foregroundColor(.red)
        }

        // MARK: Functions

        func validatePassword() -> Bool {
            return true
        }

        var isValidInput: Bool {
            if !username.isEmpty && !password.isEmpty && validatePassword() { return true }
            return false
        }

        func signIn() {
            loginStatus = .loading

            Task { @MainActor in
                do {
                    try await source.handleBasicAuth(id: username, password: password)
                    source.user = try await source.getAuthenticatedUser()
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    self.loginStatus = .failed(error)
                }
            }
        }
    }
}

extension ContentSourceView {
    struct AuthenticatedUserView: View {
        @EnvironmentObject var source: DaisukeEngine.LocalContentSource
        var user: DSKCommon.User
        @State var presentShouldSync = false
        @Binding var presentWebView: Bool
        var body: some View {
            HStack(alignment: .center) {
                BaseImageView(url: URL(string: user.avatar ?? ""))
                    .background(.gray)
                    .clipShape(Circle())
                    .frame(width: 75, height: 75)
                    .padding(.all, 7)

                Text(user.username)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            if let info = user.info {
                Section {
                    InteractiveTagView(info) { tag in
                        Text(tag)
                            .modifier(ProfileTagStyle())
                    }
                } header: {
                    Text("Info")
                }
            }
            if source.canSyncUserLibrary {
                Section {
                    Button {
                        presentShouldSync.toggle()
                    } label: {
                        Label("Sync Library", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Sync")
                }
                .alert("Sync Library", isPresented: $presentShouldSync, actions: {
                    Button("Cancel", role: .cancel) {}
                    Button("Proceed") {
                        Task {
                            do {
                                try await handleContentSync()
                            } catch {
                                await MainActor.run(body: {
                                    ToastManager.shared.error(error)
                                })
                            }
                            ToastManager.shared.loading = false
                        }
                    }
                }, message: {
                    Text("Are you sure you want to sync your \(source.name) library?")
                })
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        do {
                            guard let authMethod = source.authMethod else {
                                return
                            }
                            switch authMethod {
                            case .username_pw, .email_pw, .oauth:
                                try await source.handleUserSignOut()
                            case .web:
                                presentWebView.toggle()
                            }
                            try await source.user = source.getAuthenticatedUser()
                        } catch {
                            ToastManager.shared.error(error)
                        }
                    }
                }
            }
        }

        func handleContentSync() async throws {
            await MainActor.run(body: {
                ToastManager.shared.loading.toggle()
            })
            try await source.syncUserLibrary()
            await MainActor.run(body: {
                ToastManager.shared.info("Synced!")
            })
        }
    }
}

// MARK: WebView

struct WebAuthWebView: UIViewControllerRepresentable {
    var source: any AuthSource
    func makeUIViewController(context _: Context) -> some Controller {
        let view = Controller()
        view.source = source
        return view
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}

extension WebAuthWebView {
    class Controller: UIViewController, WKUIDelegate {
        var webView: WKWebView!
        var source: (any AuthSource)!

        override func viewDidLoad() {
            super.viewDidLoad()
            let webConfiguration = WKWebViewConfiguration()

            webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
            webView.customUserAgent = Preferences.standard.userAgent
            webView.uiDelegate = self
            webView.navigationDelegate = self
            view.addSubview(webView)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            Task { @MainActor in
                do {
                    let dskRequest = try await source.willRequestAuthenticationWebView()
                    let request = try dskRequest.toURLRequest()
                    let _ = self.webView.load(request)
                } catch {
                    ToastManager.shared.error(error)
                }
            }
        }
    }
}

extension WebAuthWebView.Controller: WKNavigationDelegate {
    func webView(_: WKWebView, decidePolicyFor _: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { [weak self] cookies in

            cookies.forEach { cookie in
                AF.session.configuration.httpCookieStorage?.setCookie(cookie)
                Task { @MainActor in
                    guard let self else { return }

                    do {
                        let dsk = DSKCommon.Cookie(name: cookie.name, value: cookie.value)
                        let isValidCookie = try await self.source.didReceiveAuthenticationCookieFromWebView(cookie: dsk)
                        if isValidCookie {
                            ToastManager.shared.info("[\(self.source.name)] Logged In!")
                        }
                    } catch {
                        ToastManager.shared.error(error)
                        Logger.shared.error(error.localizedDescription)
                    }
                }
            }
        }
    }
}
