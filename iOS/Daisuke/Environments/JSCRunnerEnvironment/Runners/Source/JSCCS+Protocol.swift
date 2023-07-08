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

// MARK: - Source Protocol

protocol ContentSource {
    // Core
    func getContent(id: String) async throws -> DSKCommon.Content
    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter]
    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData
    
    // Search
    func getDirectory(_ request: DSKCommon.SearchRequest) async throws -> DSKCommon.PagedResult
    func getDirectoryConfig() async throws -> DSKCommon.DirectoryConfig
    
    // Explore
    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt]
    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection
    func willResolveExploreCollections() async throws
    
    // Tags
    func getAllTags() async throws -> [DaisukeEngine.Structs.Property]
    func getRecommendedTags() async throws -> [DaisukeEngine.Structs.ExploreTag]

    // Image Request Handler
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request
    
    // Chapter Event Handlers
    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws
    func onChapterRead(contentId: String, chapterId: String) async throws

    // Content Event Handlers
    func onContentsAddedToLibrary(ids: [String]) async throws
    func onContentsRemovedFromLibrary(ids: [String]) async throws
    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws
    
    // Chapter Sync Handler
    func getReadChapterMarkers(contentId: String) async throws -> [String]

    // Library Sync Handler
    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent]

    // Deep Link
    func getIdentifiers(for id: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer?
}
 
