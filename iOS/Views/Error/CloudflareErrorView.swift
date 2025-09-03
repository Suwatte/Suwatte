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
    let sourceID: String
    let action: () async -> Void
    let resolutionURL: String?
    @State var showSheet: Bool = false
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

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
        .fullScreenCover(isPresented: $showSheet, onDismiss: { Task { await action() }}) {
            SmartNavigationView {
                CloudFlareWebView(sourceID: sourceID, resolutionURL: resolutionURL)
                    .navigationBarTitle("Cloudflare Resolve", displayMode: .inline)
                    .closeButton()
                    .tint(accentColor)
                    .accentColor(accentColor)
            }
        }
    }
}

extension CloudFlareErrorView {
    struct CloudFlareWebView: UIViewControllerRepresentable {
        var sourceID: String
        var resolutionURL: String?
        func makeUIViewController(context _: Context) -> some CloudFlareWebViewViewController {
            let view = CloudFlareWebViewViewController()
            view.sourceID = sourceID
            view.resolutionURL = resolutionURL
            return view
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context) {}
    }

    class CloudFlareWebViewViewController: UIViewController, WKUIDelegate {
        var webView: WKWebView!
        var sourceID: String!
        var resolutionURL: String?
        var triggered = false
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

            if let resolutionURL {
                let url = URL(string: resolutionURL)
                guard let url else {
                    StateManager.shared.alert(title: "Invalid Resolution URL", message: "The source failed to provide a valid url.")
                    return
                }
                let request = URLRequest(url: url)
                _ = webView.load(request)
            } else {
                Task { @MainActor in
                    guard let source = await DSK.shared.getSource(id: sourceID) else {
                        StateManager.shared.alert(title: "Error", message: "Unable to Locate Source")
                        return
                    }
                    var url = source.cloudflareResolutionURL ?? URL(string: source.info.website ?? "")
                    guard let url else {
                        StateManager.shared.alert(title: "Error", message: "Invalid URL Provided")
                        return
                    }
                    let request = URLRequest(url: url)
                    let _ = self.webView.load(request)
                }
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
            for cookie in cookies {
                AF.session.configuration.httpCookieStorage?.setCookie(cookie)
            }
        }
    }
}
