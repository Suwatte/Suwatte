//
//  WK+SyncableSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-05.
//

import Foundation

extension WKContentSource: SyncableSource {
    func onContentsAddedToLibrary(ids: [String]) async throws {
        let body = "await onContentsAddedToLibrary(ids);"
        let arguments = ["ids": ids]
        try await eval(body, arguments)
    }

    func onContentsRemovedFromLibrary(ids: [String]) async throws {
        let body = "await onContentsRemovedFromLibrary(ids);"
        let arguments = ["ids": ids]
        try await eval(body, arguments)
    }

    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws {
        let body = "await onContentsReadingFlagChanged(ids, flag);"
        let arguments: [String: Any] = ["ids": ids, "flag": flag.rawValue]
        try await eval(body, arguments)
    }

    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws {
        let body = "await onChaptersMarked(contentId, chapterIds, completed);"
        let arguments: [String: Any] = ["contentId": contentId, "chapterIds": chapterIds, "completed": completed]
        try await eval(body, arguments)
    }

    func onChapterRead(contentId: String, chapterId: String) async throws {
        let body = "await onChapterRead(contentId, chapterId);"
        let arugments = ["contentId": contentId, "chapterId": chapterId]
        try await eval(body, arugments)
    }

    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent] {
        let body = "return syncUserLibrary(library);"
        let arguments = ["library": library]
        return try await eval(body, arguments, to: [DSKCommon.DownSyncedContent].self)
    }

    func getReadChapterMarkers(contentId: String) async throws -> [String] {
        let body = "return getReadChapterMarkers(contentId);"
        let arguments = ["contentId": contentId]
        return try await eval(body, arguments, to: [String].self)
    }
}
