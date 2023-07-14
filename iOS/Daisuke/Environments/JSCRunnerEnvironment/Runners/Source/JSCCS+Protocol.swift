//
//  ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//

import Foundation

typealias DSK = DaisukeEngine
typealias DSKCommon = DaisukeEngine.Structs

// MARK: - Source Info

struct SourceInfo: RunnerInfo {
    var id: String
    var name: String
    var version: Double
    var minSupportedAppVersion: String?
    var thumbnail: String?
    
    var website: String
    var supportedLanguages: [String]
}

struct SourceConfig: Parsable {
    var chapterDataCachingDisabled: Bool?;
    var chapterDateUpdateDisabled: Bool?;
    var cloudflareResolutionURL: String?;
}
