//
//  DSK+HostedContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-24.
//

import Foundation
import Alamofire

extension DaisukeEngine {
    final class HostedContentSource : DaisukeContentSource {
        
        var host: URL
        required init(host: URL, info: ContentSourceInfo) {
            self.host = host
            let dateFormatter = DateFormatter()
            self.decoder = JSONDecoder()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            super.init(info: info)
        }

        let decoder: JSONDecoder


        override func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
            let url = URL(string: "/source/\(sourceInfo.id)/content/\(id)", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            
            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable(DaisukeEngine.Structs.Content.self, decoder: decoder)
            return try await task.value

        }
        
        override func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter] {
            let url = URL(string: "/source/\(sourceInfo.id)/content/\(contentId)/chapters", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            
            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable([DaisukeEngine.Structs.Chapter].self, decoder: decoder)
            return try await task.value
        }
        
        override func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData {
            let url = URL(string: "/source/\(sourceInfo.id)/content/\(contentId)/chapters/\(chapterId)", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            
            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable(DaisukeEngine.Structs.ChapterData.self, decoder: decoder)
            return try await task.value
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
            let url = URL(string: "/source/\(sourceInfo.id)/search", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            let body: Parameters = ["query": try query.asDictionary()]
            let task = AF.request(url, method: .post, parameters: body, encoding: URLEncoding.httpBody)
                .validate()
                .serializingDecodable(DSKCommon.PagedResult.self, decoder: decoder)

            return try await task.value
        }
        
        override func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
            let url = URL(string: "/source/\(sourceInfo.id)/filters", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            
            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable([DaisukeEngine.Structs.Filter].self, decoder: decoder)
            return try await task.value
        }
        
        override func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
            let url = URL(string: "/source/\(sourceInfo.id)/sorters", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            
            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable([DaisukeEngine.Structs.SortOption].self, decoder: decoder)
            return try await task.value

        }
        
        
    }
}
