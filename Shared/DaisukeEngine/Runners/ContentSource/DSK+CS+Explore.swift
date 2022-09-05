//
//  DSK+CS+Tags.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation
import JavaScriptCore

// MARK: Tags

extension DaisukeEngine.ContentSource {
    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
        try await callMethodReturningDecodable(method: "getSourceTags", arguments: [], resolvesTo: [DaisukeEngine.Structs.Property].self)
    }

    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.Tag]? {
        let method = "getExplorePageTags"
        if !methodExists(method: method) { return nil }

        return try await callMethodReturningDecodable(method: method, arguments: [], resolvesTo: [DaisukeEngine.Structs.Tag].self)
    }
}

// MARK: Explore Section

extension DaisukeEngine.ContentSource {
    typealias CollectionExcerpt = DSKCommon.CollectionExcerpt

    func createExplorePageCollections() async throws -> [CollectionExcerpt] {
        try await callMethodReturningDecodable(method: "createExploreCollections", arguments: [], resolvesTo: [CollectionExcerpt].self)
    }

    func resolveExplorePageCollection(_ excerpt: CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
        let excerpt = try excerpt.asDictionary()
        return try await callMethodReturningDecodable(method: "resolveExploreCollection", arguments: [excerpt], resolvesTo: DSKCommon.ExploreCollection.self)
    }
}
