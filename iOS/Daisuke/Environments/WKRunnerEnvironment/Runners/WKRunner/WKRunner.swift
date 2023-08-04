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
    internal let wv: WKWebView!
    internal var configCache: [String : DSKCommon.DirectoryConfig] = [:]
    
    
    init(instance: InstanceInformation, webview: WKWebView) async throws {
        self.instance = instance
        self.wv = webview
        self.info = .init(id: "default", name: "", version: 1.0, website: "", minSupportedAppVersion: nil, thumbnail: nil, supportedLanguages: nil, nsfw: nil)
        self.intents = .init(preferenceMenuBuilder: false, authenticatable: false, authenticationMethod: .unknown, basicAuthLabel: nil, imageRequestHandler: false, pageLinkResolver: false, libraryPageLinkProvider: false, browsePageLinkProvider: false, chapterEventHandler: false, contentEventHandler: false, chapterSyncHandler: false, librarySyncHandler: false, hasTagsView: false, pageReadHandler: false, providesReaderContext: false, canRefreshHighlight: false, isContextMenuProvider: false, advancedTracker: false)
        
        let infoScript = """
            return JSON.stringify(RunnerObject.info)
        """
        
        let intentsScript = """
            return JSON.stringify(RunnerIntents)
        """
        self.info = try await eval(infoScript)
        self.intents = try await eval(intentsScript)
    }
}


class WKBootstrapper : NSObject {
    private let wv: WKWebView
    internal var isClientReady = false
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
        wv.configuration.userContentController.add(self, contentWorld: .defaultClient, name: "state")
        await withCheckedContinuation { continuation in
            if isClientReady {
                continuation.resume()
                return
            }
            self.continuation = continuation
            wv.loadHTMLString(HTML, baseURL: nil)
        }
    }
}


extension WKBootstrapper: WKScriptMessageHandler {
    private func didEnterReadyState() {
        isClientReady = true
        continuation?.resume()
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
