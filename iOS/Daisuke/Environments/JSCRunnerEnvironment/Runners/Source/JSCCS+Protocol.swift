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
    let disableChapterDataCaching: Bool?
    let disableChapterDates: Bool?
    let disableLanguageFlags: Bool?
    let disableTagNavigation: Bool?
    let disableUpdateChecks: Bool?
    let disableLibraryActions: Bool?
    let disableTrackerLinking: Bool?
    let disableCustomThumbnails: Bool?
    let disableContentLinking: Bool?
    let disableMigrationDestination: Bool?
    
    var cloudflareResolutionURL: String?
}
