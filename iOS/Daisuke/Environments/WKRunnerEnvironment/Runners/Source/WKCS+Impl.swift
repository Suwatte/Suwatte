//
//  WKCS+Impl.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation


extension WKContentSource : ContentSource {
    func getContent(id: String) async throws -> DSKCommon.Content {
        try await eval(script("let data = await RunnerObject.getContent(id);"), ["id": id])
    }
    
    func getContentChapters(contentId: String) async throws -> [DSKCommon.Chapter] {
        try await eval(script("let data = await RunnerObject.getChapters(id);"), ["id": contentId])
    }
    
    func getChapterData(contentId: String, chapterId: String) async throws -> DSKCommon.ChapterData {
        try await eval(script("let data = await RunnerObject.getChapterData(content, chapter);"), ["content": contentId, "chapter": chapterId])
    }
    
    func getAllTags() async throws -> [DaisukeEngine.Structs.Property] {
        try await eval(script("let data = await RunnerObject.getTags();"))
    }
    
    func getReadChapterMarkers(contentId: String) async throws -> [String] {
        try await eval(script("let data = await RunnerObject.getReadChapterMarkers(id);"), ["id": contentId])
    }
    
    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent] {
        try await eval(script("let data = await RunnerObject.syncUserLibrary(lib);"), ["lib": try library.asDictionary()])
    }
    
    func getIdentifiers(for id: String) async throws -> DaisukeEngine.Structs.URLContentIdentifer? {
        try await eval(script("let data = await RunnerObject.getIdentifierForURL(id);"), ["id": id])
    }
    
    func onContentsAddedToLibrary(ids: [String]) async throws {
        try await eval("await RunnerObject.onContentsAddedToLibrary(ids)", ["ids": ids])
    }
    
    func onContentsRemovedFromLibrary(ids: [String]) async throws {
        try await eval("await RunnerObject.onContentsRemovedFromLibrary(ida)", ["ids": ids])
    }
    
    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws {
        try await eval("await RunnerObject.onContentsReadingFlagChanged(ids, flag)", ["ids": ids, "flag": flag.rawValue])
    }
    
    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws {
        try await eval("await RunnerObject.onChaptersMarked(contentId, chapterIds, completed)", ["contentId": contentId, "chapterIds": chapterIds, "completed": completed])
    }
    
    func onChapterRead(contentId: String, chapterId: String) async throws {
        try await eval("await RunnerObject.onChapterRead(contentId, chapterId)", ["contentId": contentId, "chapterId": chapterId])
    }
    
    func onPageRead(contentId: String, chapterId: String, page: Int) async throws {
        let script = """
        if (!RunnerObject.onPageRead) return
        await RunnerObject.onPageRead(contentId, chapterId, page);
        """
        try await eval(script, ["contentId": contentId, "chapterId": chapterId, "page": page])
    }
    
    func provideReaderContext(for contentId: String) async throws -> DSKCommon.ReaderContext {
        try await eval(script("let data = await RunnerObject.provideReaderContext(contentId);"), ["contentId": contentId])
    }
    
    func getHighlight(highlight: DSKCommon.Highlight) async throws -> DSKCommon.Highlight {
        try await eval(script("let data = await RunnerObject.getHighlight(highlight);"), ["highlight": try highlight.asDictionary()])
    }
    
    func getContextActions(highlight: DSKCommon.Highlight) async throws -> [DSKCommon.ContextMenuGroup] {
        try await eval(script("let data = await RunnerObject.getContextActions(highlight);"), ["highlight": try highlight.asDictionary()])
    }
    
    func didTriggerContextActon(highlight: DSKCommon.Highlight, key: String) async throws {
        try await eval("await RunnerObject.didTriggerContextAction(highlight, key);", ["highlight": try highlight.asDictionary(), "key": key])
    }
    
    func overrrideDownloadRequest(_ url: String) async throws -> DSKCommon.Request? {
        try await eval(script("let data = await RunnerObject.overrideDownloadRequest(url);"), ["url": url])
    }    
}
