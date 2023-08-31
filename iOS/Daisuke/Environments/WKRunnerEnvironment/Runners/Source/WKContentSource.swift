//
//  WKContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import WebKit

final class WKContentSource: WKRunner {
    var config: SourceConfig?
    var directoryTags: [DSKCommon.Property]?

    override init(webview: WKWebView) async throws {
        try await super.init(webview: webview)

        let script = """
            const config = RunnerObject.config;
            if (!config) return null;
            return JSON.stringify(config)
        """

        let conf: SourceConfig? = try await evalNullable(script)
        config = conf
    }
}
