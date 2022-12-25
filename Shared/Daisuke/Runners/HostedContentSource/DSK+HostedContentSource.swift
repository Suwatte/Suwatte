//
//  DSK+HostedContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-24.
//

import Alamofire
import Foundation

extension DaisukeEngine {
    final class HostedContentSource: DaisukeContentSource {
        private let host: URL
        required init(host: URL, info: ContentSourceInfo) {
            self.host = host
            let dateFormatter = DateFormatter()
            decoder = JSONDecoder()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            super.init(info: info)
        }

        let decoder: JSONDecoder

        override func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
            let url = URL(string: "/source/\(id)/content/\(id)", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable(DaisukeEngine.Structs.Content.self, decoder: decoder)
            return try await task.value
        }

        override func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter] {
            let url = URL(string: "/source/\(id)/content/\(contentId)/chapters", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable([DaisukeEngine.Structs.Chapter].self, decoder: decoder)
            return try await task.value
        }

        override func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData {
            let url = URL(string: "/source/\(id)/content/\(contentId)/chapters/\(chapterId)", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable(DaisukeEngine.Structs.ChapterData.self, decoder: decoder)
            return try await task.value
        }

        override func getIdentifiers(for _: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
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

        override func resolveExplorePageCollection(_: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
            throw DSK.Errors.MethodNotImplemented
        }

        override func getSearchResults(query: DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult {
            let url = URL(string: "/source/\(id)/search", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }
            let body: Parameters = ["query": try query.asDictionary()]
            let task = AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
                .validate()
                .serializingDecodable(DSKCommon.PagedResult.self, decoder: decoder)

            return try await task.value
        }

        override func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
            let url = URL(string: "/source/\(id)/filters", relativeTo: host)

            guard let url = url else {
                throw DSK.Errors.NetworkErrorInvalidRequestURL
            }

            let task = AF.request(url, method: .get)
                .validate()
                .serializingDecodable([DaisukeEngine.Structs.Filter].self, decoder: decoder)
            return try await task.value
        }

        override func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
            let url = URL(string: "/source/\(id)/sorters", relativeTo: host)

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
