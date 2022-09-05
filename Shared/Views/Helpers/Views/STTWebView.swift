//
//  STTWebView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import SafariServices
import SwiftUI
import WebKit

import SwiftUI
import WebKit

struct STTWebView: View {
    @Environment(\.presentationMode) var presentationMode
    var url: URL?
    var body: some View {
        WebView(url: url ?? STTHost.notFound)
    }
}

extension STTWebView {
    struct WebView: UIViewRepresentable {
        var url: URL

        func makeUIView(context _: Context) -> WKWebView {
            return WKWebView()
        }

        func updateUIView(_ webView: WKWebView, context _: Context) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}
