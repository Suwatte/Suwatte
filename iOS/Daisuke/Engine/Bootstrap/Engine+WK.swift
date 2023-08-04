//
//  Engine+WK.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import WebKit


extension DSK {
    
    internal func startWKRunner(with url: URL, of instance: InstanceInformation) async throws -> WKRunner {
        func generate(for path: URL) async throws -> WKUserScript {
            var content = try String(contentsOfFile: path.relativePath, encoding: String.Encoding.utf8)
            if path.lastPathComponent == "wkFills.js" {
                content = content.replacingOccurrences(of: "ID_PLACEHOLDER", with: url.fileName)
            }
            let imm = content
            let script = await MainActor.run {
                WKUserScript(source: imm, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .defaultClient)
            }
            return script
        }
        // Required File Routes
        let commonsPath = FileManager
            .default
            .applicationSupport
            .appendingPathComponent("Runners", isDirectory: true)
            .appendingPathComponent("common.js")
        
        let messageHandlerFiles = [
            Bundle.main.url(forResource: "wkFills", withExtension: "js")!,
            Bundle.main.url(forResource: "log", withExtension: "js")!,
            Bundle.main.url(forResource: "store", withExtension: "js")!,
            Bundle.main.url(forResource: "network", withExtension: "js")!,
        ]
        
        let bootstrapFile = Bundle.main.url(forResource: "bridge", withExtension: "js")!
        
        var scripts: [WKUserScript] = []
        
        await scripts.append(try generate(for: commonsPath))
        for messageHandlerFile in messageHandlerFiles {
            await scripts.append(try generate(for: messageHandlerFile))
        }
        await scripts.append(try generate(for: url))
        await scripts.append(try generate(for: bootstrapFile))
        
        // Add Handlers
        let s = scripts
        let task =  Task { @MainActor in
            // Define Handlers
            let logger = WKHandler.LogHandler()
            let network = WKHandler.NetworkHandler()
            let store = WKHandler.StoreHandler()
            let userContentController = WKUserContentController()
            // SMH
            userContentController.add(logger, contentWorld: .defaultClient, name: "logging")
            // SMHWR
            userContentController.addScriptMessageHandler(network, contentWorld: .defaultClient, name: "networking")
            userContentController.addScriptMessageHandler(store, contentWorld: .defaultClient, name: "store")
            
            // Scripts
            s.forEach(userContentController.addUserScript)
            let config = WKWebViewConfiguration()
            config.userContentController = userContentController
            let wv = WKWebView(frame: .zero, configuration: config)
            KEY_WINDOW?.addSubview(wv)
            let bootstrapper = WKBootstrapper(wv: wv)
            await bootstrapper.prepare()
            return wv
        }
        
        let wv = await task.value
        
        let environment = try await wv
            .evaluateJavaScript("(function(){ return RunnerEnvironment })()", contentWorld: .defaultClient)
            .flatMap { $0 as? String }
            .flatMap(DSKCommon.RunnerEnvironment.init(rawValue:)) ?? .unknown
        
        var runner: WKRunner? = nil
        switch environment {
        case .source:
            runner = try await WKContentSource(instance: instance, webview: wv)
        case .tracker:
            runner = try await WKTracker(instance: instance, webview: wv)
        default:
            break
        }
        
        guard let runner else {
            throw DSK.Errors.NamedError(name: "Engine", message: "Failed to recognize runner environment.")
        }
        
        return runner
        
    }
}
