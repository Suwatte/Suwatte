//
//  WKContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//

import Foundation
import WebKit

// MARK: - Declaration
final class WKContentSource : NSObject {
    var info: SourceInfo
    var config: SourceConfig = .init()
    internal let runnerPath: URL
    internal var wv: WKWebView!
    internal var isClientReady = false
    fileprivate var continuation: CheckedContinuation<Void, Never>?
    
    
    init(_ info: SourceInfo, _ executable: URL) async {
        self.info = info
        self.runnerPath = executable
        super.init()
        await build()
        await prepare()
        await getInfo()
    }
}

typealias C = WKContentSource

// MARK: - Paths
extension C {
    fileprivate var commonsPath: URL {
        FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Daisuke", isDirectory: true)
            .appendingPathComponent("common.js")
    }
    
    
    fileprivate var bridgePath: URL {
        Bundle
            .main
            .url(forResource: "Bridge", withExtension: "js")!
    }
}

// MARK: - Initial Scripts
extension C {
    fileprivate func scripts() throws -> [WKUserScript] {
        let commons = try generate(for: commonsPath)
        let runner = try generate(for: runnerPath)
        let bridge = try generate(for: bridgePath)
        return [commons, runner, bridge]
    }
    fileprivate func generate(for path: URL) throws -> WKUserScript {
        let content = try String(contentsOfFile: path.relativePath, encoding: String.Encoding.utf8)
        let script = WKUserScript(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .defaultClient)
        return script
    }
}
extension C: WKScriptMessageHandler {
    internal func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let msg = message.body as? String
        guard let msg else { return }
        switch msg {
            case "loaded":
                didEnterReadyState()
            case "explore":
                config.hasExplorePage = true
            case "explore_tags":
                config.hasExplorePageTags = true
            case "source_tags":
                config.hasSourceTags = true
            case "read_markers":
                config.canFetchChapterMarkers = true
            case "sync":
                config.canSyncWithSource = true
            case "preferences":
                config.hasPreferences = true
            default:
                break
        }
    }
}

extension C {
    fileprivate func didEnterReadyState() {
        isClientReady = true
        continuation?.resume()
    }
    
    private var HTML : String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Suwatte</title>
            <script>
            </script>
        </head>
        <body>
        
        <h1>My First Heading</h1>
        <p>My first paragraph.</p>
        
        </body>
        </html>
        """
    }
    
    @MainActor
    func prepare() async {
        build()
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
// MARK: - Build
extension C {
    @MainActor
    func build() {
        // Define Handlers
        let logger = LogHandler(id: info.id)
        let network = NetworkHandler(id: info.id)
        let store = StoreHandler(id: info.id)
        // Add Handlers
        let userContentController = WKUserContentController()
        // SMH
        userContentController.add(self, contentWorld: .defaultClient, name: "state")
        userContentController.add(logger, contentWorld: .defaultClient, name: "logging")
        
        // SMHWR
        userContentController.addScriptMessageHandler(network, contentWorld: .defaultClient, name: "networking")
        userContentController.addScriptMessageHandler(store, contentWorld: .defaultClient, name: "store")
        
        // Scripts
        do {
            let s = try scripts()
            s.forEach(userContentController.addUserScript)
        } catch {
            Logger.shared.error("Failed to Load Required Libraries \(error.localizedDescription)", "WKContentSource")
        }
        
        // Combine
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        self.wv = WKWebView(frame: .zero, configuration: config)
        KEY_WINDOW?.addSubview(wv)
    }
}

// MARK: Evaluation Methods
extension C {
    internal func eval(_ str: String, _ args: [String: Any] = [:]) async throws {
        try await withCheckedThrowingContinuation({ handler in
            Task { @MainActor in
                wv.callAsyncJavaScript(str, arguments: args, in: nil, in: .defaultClient, completionHandler: { result in
                    do {
                        let _ = try result.get()
                        handler.resume()
                    } catch {
                        handler.resume(throwing: error)
                    }
                })
            }
        })
    }
    
    internal func eval<T:Decodable>(_ str: String, _ args: [String: Any] = [:], to: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation({ handler in
            Task { @MainActor in
                wv.callAsyncJavaScript(str, arguments: args, in: nil, in: .defaultClient, completionHandler: { result in
                    do {
                        let jsResult = try result.get() as? String
                        guard let jsResult, let data = jsResult.data(using: .utf8, allowLossyConversion: false) else {
                            throw DSK.Errors.InvalidJSONObject
                        }
                        let output = try DaisukeEngine.decode(data: data, to: T.self)
                        handler.resume(returning: output)
                    } catch {
                        handler.resume(throwing: error)
                    }
                })
            }
        })
    }
    
    internal func getInfo() async {
        do {
            let data = try await eval("return prepare(RUNNER.info);", to: SourceInfo.self)
            self.info = data
        } catch {
            Logger.shared.error("\(error)")
        }
    }
}
