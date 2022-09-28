//
//  CloudflareErrorView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-15.
//

import Alamofire
import SwiftUI
import UIKit
import WebKit

struct CloudFlareErrorView: View {
    var sourceID: String
    var action: () -> Void
    @State var showSheet: Bool = false

    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.shield")
                .imageScale(.large)
                .foregroundColor(.gray)
            VStack {
                Text("CloudFlare Protected Content")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("A WebView is required to resolve.")
                    .font(.caption)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
            }
            Button {
                self.showSheet.toggle()
                Logger.shared.debug("[ErrorView] [CloudFlare] Resolve for \(sourceID)")
            }
                label: {
                Text("Resolve & Retry")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 150)
                    .background(Color.accentColor)
                    .cornerRadius(7)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .fullScreenCover(isPresented: $showSheet, onDismiss: { action() }) {
            NavigationView {
                CloudFlareWebView(sourceID: sourceID)
                    .navigationBarTitle("Cloudflare Resolve", displayMode: .inline)
                    .closeButton()
            }
        }
    }
}

extension CloudFlareErrorView {
    struct CloudFlareWebView: UIViewControllerRepresentable {
        var sourceID: String
        func makeUIViewController(context _: Context) -> some CloudFlareWebViewViewController {
            let view = CloudFlareWebViewViewController()
            view.sourceID = sourceID
            return view
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context) {}
    }

    class CloudFlareWebViewViewController: UIViewController, WKUIDelegate {
        var webView: WKWebView!
        var sourceID: String!

        override func viewDidLoad() {
            super.viewDidLoad()
            let webConfiguration = WKWebViewConfiguration()

            webView = WKWebView(frame: view.bounds, configuration: webConfiguration)
            webView.customUserAgent = STT_USER_AGENT
            webView.uiDelegate = self
            webView.navigationDelegate = self
            view.addSubview(webView)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            Task { @MainActor in
                guard let url = try? await DaisukeEngine.shared.getSource(with: sourceID)?.willAttemptCloudflareVerification() else {
                    return
                }

                let request = URLRequest(url: url)
                self.webView.load(request)
            }
        }
    }
}

extension CloudFlareErrorView.CloudFlareWebViewViewController: WKNavigationDelegate {
    func webView(_: WKWebView, decidePolicyFor _: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in

            cookies.forEach { cookie in
                AF.session.configuration.httpCookieStorage?.setCookie(cookie)
            }
        }
    }
}
