//
//  JSCC+ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation

private typealias CollectionExcerpt = DSKCommon.CollectionExcerpt

extension JSCContentSource: ContentSource {
    func getContent(id: String) async throws -> DSKCommon.Content {
        try await callMethodReturningObject(method: "getContent", arguments: [id], resolvesTo: DaisukeEngine.Structs.Content.self)
    }

    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter] {
        try await callMethodReturningDecodable(method: "getChapters", arguments: [contentId], resolvesTo: [DaisukeEngine.Structs.Chapter].self)
    }

    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData {
        try await callMethodReturningObject(method: "getChapterData", arguments: [contentId, chapterId], resolvesTo: DaisukeEngine.Structs.ChapterData.self)
    }

    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
        try await callMethodReturningDecodable(method: "getSourceTags", arguments: [], resolvesTo: [DaisukeEngine.Structs.Property].self)
    }

    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.ExploreTag]? {
        let method = "getExplorePageTags"
        if !methodExists(method: method) { return nil }

        return try await callMethodReturningDecodable(method: method, arguments: [], resolvesTo: [DaisukeEngine.Structs.ExploreTag].self)
    }

    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt] {
        try await callMethodReturningDecodable(method: "createExploreCollections", arguments: [], resolvesTo: [CollectionExcerpt].self)
    }

    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
        let excerpt = try excerpt.asDictionary()
        return try await callMethodReturningDecodable(method: "resolveExploreCollection", arguments: [excerpt], resolvesTo: DSKCommon.ExploreCollection.self)
    }

    func willResolveExploreCollections() async throws {
        try await callOptionalVoidMethod(method: "willResolveExploreCollections", arguments: [])
    }

    func getSearchResults(_ query: DSKCommon.SearchRequest) async throws -> DSKCommon.PagedResult {
        let query = try query.asDictionary()
        return try await callMethodReturningObject(method: "getSearchResults", arguments: [query], resolvesTo: DaisukeEngine.Structs.PagedResult.self)
    }

    func getSearchFilters() async throws -> [DSKCommon.Filter] {
        guard runnerClass.hasProperty("getSearchFilters") else {
            return []
        }
        return try await callMethodReturningDecodable(method: "getSearchFilters", arguments: [], resolvesTo: [DaisukeEngine.Structs.Filter].self)
    }

    func getSearchSortOptions() async throws -> [DSKCommon.SortOption] {
        guard runnerClass.hasProperty("getSearchSorters") else {
            return []
        }
        return try await callMethodReturningDecodable(method: "getSearchSorters", arguments: [], resolvesTo: [DaisukeEngine.Structs.SortOption].self)
    }

    func getIdentifiers(for id: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
        guard runnerClass.hasProperty("handleIdentifierForUrl") else {
            return nil
        }
        return try await callMethodReturningDecodable(method: "handleIdentifierForUrl", arguments: [id], resolvesTo: DSKCommon.URLContentIdentifer.self)
    }

    func getSourcePreferences() async throws -> [DSKCommon.PreferenceGroup] {
        return try await callContextMethod(method: "getSourcePreferences", resolvesTo: [DSKCommon.PreferenceGroup].self)
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
}
