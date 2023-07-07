//
//  JSCCS+Implementation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-06.
//

import Foundation


extension JSCContentSource: ContentSource {
    func getContent(id: String) async throws -> DSKCommon.Content {
        try await callMethodReturningObject(method: "getContent", arguments: [id], resolvesTo: DSKCommon.Content.self)
    }
    
    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter] {
        try await callMethodReturningDecodable(method: "getChapters", arguments: [contentId], resolvesTo: [DSKCommon.Chapter].self)
    }
    
    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData {
        try await callMethodReturningObject(method: "getChapterData", arguments: [contentId, chapterId], resolvesTo: DaisukeEngine.Structs.ChapterData.self)
    }
    
    func getDirectory(_ request: DSKCommon.SearchRequest) async throws -> DSKCommon.PagedResult {
        let request = try request.asDictionary()
        return try await callMethodReturningObject(method: "getDirectory", arguments: [request], resolvesTo: DaisukeEngine.Structs.PagedResult.self)
    }
    
    func getDirectoryConfig() async throws -> DSKCommon.DirectoryConfig {
        try await callMethodReturningDecodable(method: "getDirectoryConfig", arguments: [], resolvesTo: DSKCommon.DirectoryConfig.self)
    }
    
    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt] {
        try await callMethodReturningDecodable(method: "createExploreCollections", arguments: [], resolvesTo: [DSKCommon.CollectionExcerpt].self)
    }
    
    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
        let excerpt = try excerpt.asDictionary()
        return try await callMethodReturningDecodable(method: "resolveExploreCollection", arguments: [excerpt], resolvesTo: DSKCommon.ExploreCollection.self)
    }
    
    func willResolveExploreCollections() async throws {
        try await callOptionalVoidMethod(method: "willResolveExploreCollections", arguments: [])
    }
    
    func getAllTags() async throws -> [DaisukeEngine.Structs.Property] {
        try await callMethodReturningDecodable(method: "getAllTags", arguments: [], resolvesTo: [DSKCommon.Property].self)
    }
    
    func getRecommendedTags() async throws -> [DaisukeEngine.Structs.ExploreTag] {
        return try await callMethodReturningDecodable(method: "getRecommendedTags", arguments: [], resolvesTo: [DaisukeEngine.Structs.ExploreTag].self)
    }
    
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request {
        return try await callMethodReturningDecodable(method: "willRequestImage", arguments: [imageURL.absoluteString], resolvesTo: DSKCommon.Request.self)
    }
    
    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws {
        try await callOptionalVoidMethod(method: "onChaptersMarked", arguments: [contentId, chapterIds, completed])
    }
    
    func onChapterRead(contentId: String, chapterId: String) async throws {
        try await callOptionalVoidMethod(method: "onChapterRead", arguments: [contentId, chapterId])
    }
    
    func onContentsAddedToLibrary(ids: [String]) async throws {
        try await callOptionalVoidMethod(method: "onContentsAddedToLibrary", arguments: [ids])
    }
    
    func onContentsRemovedFromLibrary(ids: [String]) async throws {
        try await callOptionalVoidMethod(method: "onContentsRemovedFromLibrary", arguments: [ids])
    }
    
    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws {
        try await callOptionalVoidMethod(method: "onContentsReadingFlagChanged", arguments: [ids, flag.rawValue])
    }
    
    func getReadChapterMarkers(contentId: String) async throws -> [String] {
        return try await callMethodReturningDecodable(method: "getReadChapterMarkers", arguments: [contentId], resolvesTo: [String].self)
    }
    
    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent] {
        let data = try DaisukeEngine.encode(value: library)
        let library = try JSONSerialization.jsonObject(with: data)
        return try await callMethodReturningDecodable(method: "syncUserLibrary", arguments: [library], resolvesTo: [DSKCommon.DownSyncedContent].self)
    }
    
    func buildPreferenceMenu() async throws -> [DSKCommon.PreferenceGroup] {
        return try await callContextMethod(method: "generatePreferenceMenu", resolvesTo: [DSKCommon.PreferenceGroup].self)
    }
    
    func getAuthenticatedUser() async throws -> DSKCommon.User? {
        return try await callMethodReturningDecodable(method: "getAuthenticatedUser", arguments: [], resolvesTo: DSKCommon.User?.self)
    }
    
    func handleUserSignOut() async throws {
        try await callOptionalVoidMethod(method: "handleUserSignOut", arguments: [])
    }
    
    func handleBasicAuthentication(id: String, password: String) async throws {
        try await callOptionalVoidMethod(method: "handleBasicAuth", arguments: [id, password])
    }
    
    func willRequestAuthenticationWebView() async throws -> DSKCommon.Request {
        return try await callMethodReturningObject(method: "willRequestWebViewAuth", arguments: [], resolvesTo: DSKCommon.Request.self)
    }
    
    func didReceiveAuthenticationCookieFromWebView(cookie: DSKCommon.Cookie) async throws -> Bool {
        return try await callMethodReturningDecodable(method: "didReceiveAuthenticationCookieFromWebView", arguments: [cookie.name], resolvesTo: Bool.self)
    }
    
    func updateSourcePreference(key: String, value: Any) async {
        let context = runnerClass.context!
        let function = context.evaluateScript("updateSourcePreferences")
        function?.daisukeCall(arguments: [key, value], onSuccess: { _ in
            context.evaluateScript("console.log('[\(key)] Preference Updated')")
        }, onFailure: { error in
            context.evaluateScript("console.error('[\(key)] Preference Failed To Update: \(error)')")
            
        })
    }
    
    func getIdentifiers(for id: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
        return try await callMethodReturningDecodable(method: "getIdentifierForURL", arguments: [id], resolvesTo: DSKCommon.URLContentIdentifer?.self)
    }
    
    
}
