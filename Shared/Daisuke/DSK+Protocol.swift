//
//  DSK+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Foundation
import JavaScriptCore

protocol DaisukeInterface: Codable, Hashable, Identifiable {}

protocol DaisukeRunnerProtocol {
    var runnerClass: JSValue { get }
    var info: DaisukeRunnerInfoProtocol { get }
    var runnerType: DaisukeEngine.RunnerType { get }
}

protocol DaisukeRunnerInfoProtocol: Parsable {
    var id: String { get }
    var name: String { get }
    var version: Double { get }
    var authors: [String]? { get }
    var minSupportedAppVersion: String? { get }
}

extension DaisukeEngine {
    enum RunnerType: Int, Codable {
        case CONTENT_SOURCE, SERVICE

        var description: String {
            switch self {
            case .CONTENT_SOURCE:
                return "Content Source"
            case .SERVICE:
                return "Service"
            }
        }
    }
}

protocol DSKCSBase {
    var name: String { get }
    var version: Double { get }
    var id: String { get }
}
struct ContentSourceInfo: DaisukeRunnerInfoProtocol {
    var id: String
    var name: String
    var version: Double
    var authors: [String]?

    var minSupportedAppVersion: String?
    var website: String
    var supportedLanguages: [String]
    var VXI: String?

    var hasExplorePage: Bool
    var thumbnail: String?

    var authMethod: DSKCommon.AuthMethod?
    var contentSync: Bool?

    var canSync: Bool {
        authMethod != nil && contentSync != nil && contentSync!
    }
}
class DaisukeContentSource: DSKCSBase, ObservableObject, Identifiable, Equatable {
    var sourceInfo: ContentSourceInfo
    
    var id: String {
        sourceInfo.id
    }
    
    var name: String {
        sourceInfo.name
    }
    
    var version: Double {
        sourceInfo.version
    }
    
    static func == (lhs: DaisukeContentSource, rhs: DaisukeContentSource) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
    
    init(info: ContentSourceInfo) {
        self.sourceInfo = info
    }

    func getContent(id: String) async throws -> DaisukeEngine.Structs.Content {
        throw DSK.Errors.MethodNotImplemented

    }
    func getContentChapters(contentId: String) async throws -> [DaisukeEngine.Structs.Chapter]{
        throw DSK.Errors.MethodNotImplemented

    }
    func getChapterData(contentId: String, chapterId: String) async throws -> DaisukeEngine.Structs.ChapterData{
        throw DSK.Errors.MethodNotImplemented

    }
    func getIdentifiers(for url: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer?{
        throw DSK.Errors.MethodNotImplemented

    }

    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property]{
        throw DSK.Errors.MethodNotImplemented

    }
    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.Tag]?{
        throw DSK.Errors.MethodNotImplemented

    }
    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt]{
        throw DSK.Errors.MethodNotImplemented

    }
    func resolveExplorePageCollection(_ excerpt: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection{
        throw DSK.Errors.MethodNotImplemented

    }
//
    func getSearchResults(query: DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult{
        throw DSK.Errors.MethodNotImplemented

    }
    func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter]{
        throw DSK.Errors.MethodNotImplemented

    }
    func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption]{
        throw DSK.Errors.MethodNotImplemented

    }
}

