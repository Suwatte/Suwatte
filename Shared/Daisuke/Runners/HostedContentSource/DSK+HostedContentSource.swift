//
//  DSK+HostedContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-24.
//

import Foundation


extension DaisukeEngine {
    final class HostedContentSource : DaisukeContentSource {
        
        var host: URL
        required init(host: URL, info: ContentSourceInfo) {
            self.host = host
            super.init(info: info)
        }

        
        override func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter] {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getIdentifiers(for url: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getExplorePageTags() async throws -> [DaisukeEngine.Structs.Tag]? {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt] {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
            throw DSK.Errors.MethodNotImplemented
        }
        
        override func getSearchResults(query: DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
            throw DSK.Errors.MethodNotImplemented

        }
        
        override func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
            throw DSK.Errors.MethodNotImplemented

        }
        
        
    }
}
