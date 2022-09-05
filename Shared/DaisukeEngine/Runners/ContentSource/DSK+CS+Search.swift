//
//  DSK+CS+Search.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation
import JavaScriptCore

extension DaisukeEngine.ContentSource {
    func getSearchResults(query: DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult {
        let queryValue = JSValue(object: try query.asDictionary(), in: runnerClass.context)
        guard let queryValue = queryValue else {
            throw DaisukeEngine.Errors.NamedError(name: "Swift to JS", message: "Unable to Convert SearchRequest to JS Object")
        }
        return try await callMethodReturningObject(method: "getSearchResults", arguments: [queryValue], resolvesTo: DaisukeEngine.Structs.PagedResult.self)
    }

    func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
        guard runnerClass.hasProperty("getSearchFilters") else {
            return []
        }
        return try await callMethodReturningDecodable(method: "getSearchFilters", arguments: [], resolvesTo: [DaisukeEngine.Structs.Filter].self)
    }

    func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
        guard runnerClass.hasProperty("getSearchSorters") else {
            return []
        }
        return try await callMethodReturningDecodable(method: "getSearchSorters", arguments: [], resolvesTo: [DaisukeEngine.Structs.SortOption].self)
    }
}
