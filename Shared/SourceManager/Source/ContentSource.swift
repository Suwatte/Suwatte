//
//  ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-02-24.
//

import Foundation

// MARK: - Source Info
struct SourceInfo: Decodable {
    var id: String
    var name: String
    var version: Double
    
    var authors: [String]?
    var minSupportedAppVersion: String?
    var website: String
    var supportedLanguages: [String]
    var thumbnail: String?
    
    static let placeholder = SourceInfo(id: ".stt", name: "Source", version: 0.1, website: STTHost.root.absoluteString, supportedLanguages: [])
}

struct SourceConfig {
    var hasExplorePage = false
    var hasExplorePageTags = false
    var hasSourceTags = false
    var canFetchChapterMarkers = false
    var canSyncWithSource = false
    var hasPreferences = false
    var authenticationMethod: DSKCommon.AuthMethod? = nil
    var hasThumbnailInterceptor = false
    var hasCustomCloudflareRequest = false
}

// MARK: - Source Protocol
protocol ContentSource: Equatable {
    var info: SourceInfo { get set }
    var config: SourceConfig { get set }

    func getContent(id: String) async throws -> DSKCommon.Content
    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter]
    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData
    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property]
    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.ExploreTag]?
    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt]
    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection
    func willResolveExploreCollections() async throws
    func getSearchResults(_ query : DSKCommon.SearchRequest) async throws -> DSKCommon.PagedResult
    func getSearchFilters() async throws -> [DSKCommon.Filter]
    func getSearchSortOptions() async throws -> [DSKCommon.SortOption]
    func getIdentifiers(for id: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer?
    func getSourcePreferences() async throws -> [DSKCommon.PreferenceGroup]
}

// MARK: - Modifiable Source Protocol
protocol ModifiableSource : ContentSource {
    func getCloudflareVerificationRequest()  async throws -> DSKCommon.Request
    func willRequestImage(request: DSKCommon.Request) async throws -> DSKCommon.Request
}

// MARK: - Syncable Source Protocol
protocol SyncableSource: ContentSource {
    func onContentsAddedToLibrary(ids: [String]) async throws
    func onContentsRemovedFromLibrary(ids: [String]) async throws
    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws
    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws
    func onChapterRead(contentId: String, chapterId: String) async throws
    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent]
    func getReadChapterMarkers(contentId: String) async throws -> [String]
}

// MARK: - Auth Source
protocol AuthSource : ContentSource {
    func getAuthenticatedUser() async throws -> DSKCommon.User?
    func handleBasicAuthentication(id: String, password: String) async throws
    func handleUserSignOut() async throws
    func willRequestAuthenticationWebView() async throws -> DSKCommon.Request
    func didReceiveAuthenticationCookieFromWebView(cookie: DSKCommon.Cookie) async throws -> Bool
}

// MARK: - Identifiers
extension ContentSource {
    var id: String {
        info.id
    }
    var name: String {
        info.name
    }

    var version: Double {
        info.version
    }
}

// MARK: - Equatable
extension ContentSource {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}

// MARK: - Alias
typealias CS = ContentSource
typealias AnyContentSource = any ContentSource

