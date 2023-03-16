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

struct ContentSourceInfo: Codable, Parsable {
    var id: String
    var name: String
    var version: Double
    var authors: [String]?
    var minSupportedAppVersion: String?
    var website: String
    var supportedLanguages: [String]
    var thumbnail: String?
}

class DaisukeContentSource: DSKCSBase, ObservableObject, Identifiable, Equatable , ContentSource {
    func getSourcePreferences() async throws -> [DSKCommon.PreferenceGroup] {
        throw DSK.Errors.MethodNotImplemented
    }
    
    var config: SourceConfig
    
    
    var info: SourceInfo

    var id: String {
        info.id
    }

    var name: String {
        info.name
    }

    var version: Double {
        info.version
    }

    static func == (lhs: DaisukeContentSource, rhs: DaisukeContentSource) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    init(info: ContentSourceInfo) {
        self.info = SourceInfo(id: info.id, name: info.name, version: info.version, website: info.website, supportedLanguages: info.supportedLanguages)
        self.config = .init()
    }

    func getContent(id _: String) async throws -> DaisukeEngine.Structs.Content {
        throw DSK.Errors.MethodNotImplemented
    }

    func getContentChapters(contentId _: String) async throws -> [DaisukeEngine.Structs.Chapter] {
        throw DSK.Errors.MethodNotImplemented
    }

    func getChapterData(contentId _: String, chapterId _: String) async throws -> DaisukeEngine.Structs.ChapterData {
        throw DSK.Errors.MethodNotImplemented
    }

    func getIdentifiers(for _: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
        throw DSK.Errors.MethodNotImplemented
    }

    func getSourceTags() async throws -> [DaisukeEngine.Structs.Property] {
        throw DSK.Errors.MethodNotImplemented
    }

    func getExplorePageTags() async throws -> [DaisukeEngine.Structs.ExploreTag]? {
        throw DSK.Errors.MethodNotImplemented
    }

    func createExplorePageCollections() async throws -> [DSKCommon.CollectionExcerpt] {
        throw DSK.Errors.MethodNotImplemented
    }

    func resolveExplorePageCollection(_: DSKCommon.CollectionExcerpt) async throws -> DSKCommon.ExploreCollection {
        throw DSK.Errors.MethodNotImplemented
    }
    
    func willResolveExploreCollections() async throws {
        throw DSK.Errors.MethodNotImplemented
    }

//
    func getSearchResults(_ query : DaisukeEngine.Structs.SearchRequest) async throws -> DaisukeEngine.Structs.PagedResult {
        throw DSK.Errors.MethodNotImplemented
    }

    func getSearchFilters() async throws -> [DaisukeEngine.Structs.Filter] {
        throw DSK.Errors.MethodNotImplemented
    }

    func getSearchSortOptions() async throws -> [DaisukeEngine.Structs.SortOption] {
        throw DSK.Errors.MethodNotImplemented
    }
}
