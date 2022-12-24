//
//  DSK+ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Combine
import Foundation
import JavaScriptCore

extension DaisukeEngine {
    final class LocalContentSource: DaisukeContentSource, DaisukeRunnerProtocol {
        var info: DaisukeRunnerInfoProtocol
        internal var runnerClass: JSValue
        var runnerType: DaisukeEngine.RunnerType = .CONTENT_SOURCE
        required init(runnerClass: JSValue) throws {
            self.runnerClass = runnerClass

            guard let dictionary = runnerClass.forProperty("info") else {
                throw Errors.RunnerInfoInitFailed
            }

            // TODO: WTF IS THIS???
            let i = try ContentSourceInfo(value: dictionary)
            info = i
            super.init(info: i)
        }

        override func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
            try await callMethodReturningObject(method: "getContent", arguments: [id], resolvesTo: DaisukeEngine.Structs.Content.self)
        }

        override func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter] {
            try await callMethodReturningDecodable(method: "getChapters", arguments: [contentId], resolvesTo: [DaisukeEngine.Structs.Chapter].self)
        }

        override func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData {
            try await callMethodReturningObject(method: "getChapterData", arguments: [contentId, chapterId], resolvesTo: DaisukeEngine.Structs.ChapterData.self)
        }

        override func getIdentifiers(for url: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
            try await withCheckedThrowingContinuation { handler in
                guard runnerClass.hasProperty("handleIdentifierForUrl") else {
                    handler.resume(returning: nil)
                    return
                }

                runnerClass.daisukeCall(method: "handleIdentifierForUrl", arguments: [url]) { value in
                    if value.isNull {
                        handler.resume(returning: nil)
                    }

                    do {
                        let object = try DaisukeEngine.Structs.URLContentIdentifer(value: value)
                        handler.resume(returning: object)

                    } catch {
                        handler.resume(throwing: error)
                    }

                } onFailure: { error in
                    handler.resume(throwing: error)
                }
            }
        }

        override func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
            try await callMethodReturningDecodable(method: "getSourceTags", arguments: [], resolvesTo: [DaisukeEngine.Structs.Property].self)
        }

        override func getExplorePageTags() async throws -> [DaisukeEngine.Structs.Tag]? {
            let method = "getExplorePageTags"
            if !methodExists(method: method) { return nil }

            return try await callMethodReturningDecodable(method: method, arguments: [], resolvesTo: [DaisukeEngine.Structs.Tag].self)
        }

        typealias CollectionExcerpt = DSKCommon.CollectionExcerpt

        override func createExplorePageCollections() async throws -> [CollectionExcerpt] {
            try await callMethodReturningDecodable(method: "createExploreCollections", arguments: [], resolvesTo: [CollectionExcerpt].self)
        }

        override func resolveExplorePageCollection(_ excerpt: CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
            let excerpt = try excerpt.asDictionary()
            return try await callMethodReturningDecodable(method: "resolveExploreCollection", arguments: [excerpt], resolvesTo: DSKCommon.ExploreCollection.self)
        }

        override func getSearchResults(query: DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult {
            let queryValue = JSValue(object: try query.asDictionary(), in: runnerClass.context)
            guard let queryValue = queryValue else {
                throw DaisukeEngine.Errors.NamedError(name: "Swift to JS", message: "Unable to Convert SearchRequest to JS Object")
            }
            return try await callMethodReturningObject(method: "getSearchResults", arguments: [queryValue], resolvesTo: DaisukeEngine.Structs.PagedResult.self)
        }

        override func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
            guard runnerClass.hasProperty("getSearchFilters") else {
                return []
            }
            return try await callMethodReturningDecodable(method: "getSearchFilters", arguments: [], resolvesTo: [DaisukeEngine.Structs.Filter].self)
        }

        override func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
            guard runnerClass.hasProperty("getSearchSorters") else {
                return []
            }
            return try await callMethodReturningDecodable(method: "getSearchSorters", arguments: [], resolvesTo: [DaisukeEngine.Structs.SortOption].self)
        }
    }
}

// MARK: Generic Functions

extension DaisukeEngine.LocalContentSource {
    func methodExists(method: String) -> Bool {
        runnerClass.hasProperty(method)
    }

    func callOptionalVoidMethod(method: String, arguments: [Any]) async throws {
        try await withUnsafeThrowingContinuation { handler in
            guard runnerClass.hasProperty(method) else {
                handler.resume()
                return
            }

            runnerClass.daisukeCall(method: method, arguments: arguments) { _ in
                handler.resume()
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        } as Void
    }

    func callMethodReturningObject<T: Parsable>(method: String, arguments: [Any], resolvesTo _: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { handler in

            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }

            runnerClass.daisukeCall(method: method, arguments: arguments) { value in
                do {
                    let object = try T(value: value)
                    handler.resume(returning: object)
                } catch {
                    handler.resume(throwing: error)
                }

            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }

    func callMethodReturningDecodable<T: Decodable>(method: String, arguments: [Any], resolvesTo _: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { handler in
            guard runnerClass.hasProperty(method) else {
                handler.resume(throwing: DaisukeEngine.Errors.MethodNotFound(name: method))
                return
            }
            runnerClass.daisukeCall(method: method, arguments: arguments) { value in

                let str = DaisukeEngine.stringify(val: value)
                guard let str = str else {
                    handler.resume(throwing: DaisukeEngine.Errors.NamedError(name: "Invalid Return", message: "Returned Array Object cannot be converted to JSON String"))
                    return
                }
                do {
                    let jsonData = str.data(using: .utf8)!
                    let output: T = try DaisukeEngine.decode(data: jsonData, to: T.self)
                    handler.resume(returning: output)
                } catch {
                    handler.resume(throwing: error)
                }
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}

extension DaisukeEngine.LocalContentSource {
    func registerDefaultPrefs() async throws {
        let groups = try await getUserPreferences()

        guard let groups else {
            return
        }

        let prefs = groups.flatMap { $0.children }

        for pref in prefs {
            let v = DataManager.shared.getStoreValue(for: id, key: pref.key)
            guard v == nil else {
                return
            }
            DataManager.shared.setStoreValue(for: id, key: pref.key, value: pref.defaultValue)
        }
        Logger.shared.log("[\(id)] Registered Default Preferences")
    }
}
