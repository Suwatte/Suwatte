//
//  WKTracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import WebKit

final class WKTracker: WKRunner {
    var config: TrackerConfig?

    override init(webview: WKWebView, for id: String?) async throws {
        try await super.init(webview: webview, for: id)

        let script = """
            const config = RunnerObject.config;
            if (!config) return null;
            return JSON.stringify(config)
        """

        let conf: TrackerConfig? = try await evalNullable(script)
        config = conf
    }
}
