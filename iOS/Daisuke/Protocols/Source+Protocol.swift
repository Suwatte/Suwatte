//
//  Source+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

struct SourceConfig: Parsable {
    let disableChapterDataCaching: Bool?
    let disableChapterDates: Bool?
    let disableLanguageFlags: Bool?
    let disableTagNavigation: Bool?
    let disableUpdateChecks: Bool?
    let disableLibraryActions: Bool?
    let disableTrackerLinking: Bool?
    let disableCustomThumbnails: Bool?
    let disableContentLinking: Bool?
    let disableMigrationDestination: Bool?

    var cloudflareResolutionURL: String?
    let allowsMultipleInstances: Bool?

    let owningLinks: [String]?
    let requiresAuthenticationToAccessContent: Bool?
}

protocol ContentSource: DSKRunner {
    var config: SourceConfig? { get }

    func getContent(id: String) async throws -> DSKCommon.Content

    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter]

    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData

    func getAllTags() async throws -> [DaisukeEngine.Structs.Property]

    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent]

    func onContentsAddedToLibrary(ids: [String]) async throws

    func onContentsRemovedFromLibrary(ids: [String]) async throws

    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws

    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws

    func onChapterRead(contentId: String, chapterId: String) async throws

    func onPageRead(contentId: String, chapterId: String, page: Int) async throws

    func provideReaderContext(for contentId: String) async throws -> DSKCommon.ReaderContext

    func getHighlight(highlight: DSKCommon.Highlight) async throws -> DSKCommon.Highlight

    func getContextActions(highlight: DSKCommon.Highlight) async throws -> [DSKCommon.ContextMenuGroup]

    func didTriggerContextActon(highlight: DSKCommon.Highlight, key: String) async throws

    func overrrideDownloadRequest(_ url: String) async throws -> DSKCommon.Request?

    func getGroupedUpdates(for ids: [String], from date: Date) async throws -> DSKCommon.GroupedUpdateResponse

    func getProgressState(for contentId: String) async throws -> DSKCommon.ContentProgressState
}

extension ContentSource {
    var cloudflareResolutionURL: URL? {
        config?.cloudflareResolutionURL.flatMap(URL.init(string:)) ?? URL(string: info.website)
    }

    func ablityNotDisabled(_ path: KeyPath<SourceConfig, Bool?>) -> Bool {
        !(config?[keyPath: path] ?? false)
    }
}

typealias AnyContentSource = (any ContentSource)
