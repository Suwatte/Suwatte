//
//  +WebView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//
import Alamofire
import SwiftUI
import UIKit
import WebKit

extension DSKAuthView {
    struct WebViewAuthView: View {
        @State var presentSheet = false
        @EnvironmentObject var model: DSKAuthView.ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        var body: some View {
            Button {
                presentSheet.toggle()
            } label: {
                Label("Sign In", systemImage: "person.fill.viewfinder")
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $presentSheet, onDismiss: model.load) {
                SmartNavigationView {
                    WebViewRepresentable()
                        .navigationBarTitle("Login", displayMode: .inline)
                        .closeButton(title: "Done")
                        .toast()
                        .tint(accentColor)
                        .accentColor(accentColor)
                }
            }
        }
    }
}

extension DSKAuthView.WebViewAuthView {
    struct WebViewRepresentable: UIViewControllerRepresentable {
        @EnvironmentObject var model: DSKAuthView.ViewModel
        var isSignIn: Bool = true
        func makeUIViewController(context _: Context) -> some Controller {
            let view = Controller()
            view.runner = model.runner
            return view
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context) {}
    }
}

private typealias RepresentableView = DSKAuthView.WebViewAuthView.WebViewRepresentable

extension RepresentableView {
    class Controller: UIViewController, WKUIDelegate {
        var webView: WKWebView!
        var isSignIn: Bool!
        var runner: AnyRunner!

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
                    let url = try (await runner.getWebAuthRequestURL()).toURL()
                    let request = URLRequest(url: url)
                    let _ = self.webView.load(request)
                } catch {
                    Logger.shared.error(error)
                    StateManager.shared.alert(title: "Failed to Get Web Auth Request", message: "Please contact the author of this runner to ensure the provided url is valid")
                }
            }
        }
    }
}

extension RepresentableView.Controller: WKNavigationDelegate {
    func webView(_: WKWebView, decidePolicyFor _: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        if !isSignIn {
            return
        }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore

        cookieStore.getAllCookies { [unowned self] cookies in
            Task {
                for cookie in cookies {
                    guard !cookie.value.isEmpty else { continue }
                    AF.session.configuration.httpCookieStorage?.setCookie(cookie)
                    do {
                        let authenticated = try await runner.didReceiveCookieFromWebAuthResponse(name: cookie.name).state
                        guard authenticated else { continue }
                        ToastManager.shared.info("[\(runner.name)] Logged In!")
                        self.dismiss(animated: true, completion: nil)
                    } catch {
                        Logger.shared.error(error.localizedDescription)
                    }
                }

                ToastManager.shared.info("-")
            }
        }
    }
}
