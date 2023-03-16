//
//  WK+ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-05.
//

import Foundation


// MARK: - ContentSource Options
extension C : ContentSource {
    
    func getContent(id: String) async throws -> DSKCommon.Content {
        let body = "return getContent(id);"
        let arguments = ["id": id]
        return try await eval(body, arguments, to: DSKCommon.Content.self)
    }
    
    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter] {
        let body = "return getChapters(id);"
        let arguments = ["id": id]
        return try await eval(body, arguments, to: [DSKCommon.Chapter].self)
    }
    
    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData {
        let body = "return getChapterData(contentId, chapterId);"
        let arguments = ["contentId": contentId, "chapterId": chapterId]
        return try await eval(body, arguments, to: DSKCommon.ChapterData.self)
    }
    
    func getIdentifiers(for url: String) async throws -> DSKCommon.URLContentIdentifer? {
        let body = "return handleIdentifierForUrl(url);"
        let arguments = ["url": url]
        return try await eval(body, arguments, to: DSKCommon.URLContentIdentifer?.self)
    }
    
    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
        let body = "return getSourceTags();"
        return try await eval(body, to: [DaisukeEngine.Structs.Property].self)
    }
    
    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.ExploreTag]? {
        let body = "return getExplorePageTags();"
        return try await eval(body, to: [DaisukeEngine.Structs.ExploreTag]?.self)
    }
    
    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt] {
        let body = "return createExploreCollections();"
        return try await eval(body, to: [DSKCommon.CollectionExcerpt].self)
    }
    
    func willResolveExploreCollections() async throws {
        let body = "await willResolveExploreCollections();"
        try await eval(body)
    }
    
    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
        let body = "return resolveExploreCollection(e);"
        let arguments = ["e": try excerpt.asDictionary()]
        return try await eval(body, arguments, to: DSKCommon.ExploreCollection.self)
    }
    
    func getSearchResults(_ query: DSKCommon.SearchRequest) async throws -> DSKCommon.PagedResult {
        let body = "return getSearchResults(q);"
        let arguments = ["q": try query.asDictionary()]
        return try await eval(body, arguments, to: DSKCommon.PagedResult.self)
    }
    
    func getSearchFilters() async throws -> [DSKCommon.Filter] {
        let body = "return getSearchFilters();"
        return try await eval(body, to: [DSKCommon.Filter].self)
    }
    
    func getSearchSortOptions() async throws -> [DSKCommon.SortOption] {
        let body = "return getSourceTags();"
        return try await eval(body, to: [DSKCommon.SortOption].self)
    }
    
    func getSourcePreferences() async throws -> [DSKCommon.PreferenceGroup] {
        let body = "return getSourcePreferences();"
        return try await eval(body, to:[DSKCommon.PreferenceGroup].self)
    }
    
    func updateSourcePreference(key: String, value: Any) async {
        let body = "return updateSourcePreferences(key, value);"
        let arguments = ["key": key, "value": value]
        do {
            try await eval(body, arguments)
        } catch {
            Logger.shared.error("\(error)", info.id)
        }
    }
}
