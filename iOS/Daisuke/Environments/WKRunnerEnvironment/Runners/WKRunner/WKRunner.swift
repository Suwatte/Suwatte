//
//  WKRunner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import WebKit

public class WKRunner: DSKRunner {
    var info: RunnerInfo
    let instance: InstanceInformation
    var intents: RunnerIntents
    let wv: WKWebView!
    var configCache: [String: DSKCommon.DirectoryConfig] = [:]

    init(instance: InstanceInformation, webview: WKWebView) async throws {
        self.instance = instance
        wv = webview
        info = .init(id: "default", name: "", version: 1.0, website: "", rating: .SAFE, minSupportedAppVersion: nil, thumbnail: nil, supportedLanguages: nil)
        intents = .init(preferenceMenuBuilder: false, authenticatable: false, authenticationMethod: .unknown, basicAuthLabel: nil, imageRequestHandler: false, pageLinkResolver: false, libraryPageLinkProvider: false, browsePageLinkProvider: false, chapterEventHandler: false, contentEventHandler: false, chapterSyncHandler: false, librarySyncHandler: false, hasTagsView: false, pageReadHandler: false, providesReaderContext: false, canRefreshHighlight: false, isContextMenuProvider: false, advancedTracker: false)

        let infoScript = """
            return JSON.stringify(RunnerObject.info)
        """

        let intentsScript = """
            return JSON.stringify(RunnerIntents)
        """
        info = try await eval(infoScript)
        intents = try await eval(intentsScript)
    }
}

class WKBootstrapper: NSObject {
    private weak var wv: WKWebView?
    var isClientReady = false
    fileprivate var continuation: CheckedContinuation<Void, Never>?
    init(wv: WKWebView) {
        self.wv = wv
        super.init()
    }

    private var HTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <title>Suwatte</title>
        </head>
        <body>
        <h1>Suwatte</h1>
        </body>
        </html>
        """
    }

    @MainActor
    func prepare() async {
        wv?.configuration.userContentController.add(self, contentWorld: .defaultClient, name: "state")
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            wv?.loadHTMLString(HTML, baseURL: nil)
        }
    }
}

extension WKBootstrapper: WKScriptMessageHandler {
    private func didEnterReadyState() {
        isClientReady = true
        continuation?.resume()
        continuation = nil
        wv?.configuration.userContentController.removeScriptMessageHandler(forName: "state", contentWorld: .defaultClient)
        wv = nil
    }

    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        let msg = message.body as? String
        guard let msg else { return }
        switch msg {
        case "loaded":
            didEnterReadyState()
        default:
            break
        }
    }
}
