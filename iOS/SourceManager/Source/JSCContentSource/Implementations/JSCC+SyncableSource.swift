//
//  JSCC+SyncableSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-18.
//

import Foundation

extension JSCC: SyncableSource {
    func onContentsAddedToLibrary(ids: [String]) async throws {
        try await callOptionalVoidMethod(method: "onContentsAddedToLibrary", arguments: [ids])
    }

    func onContentsRemovedFromLibrary(ids: [String]) async throws {
        try await callOptionalVoidMethod(method: "onContentsRemovedFromLibrary", arguments: [ids])
    }

    func onContentsReadingFlagChanged(ids: [String], flag: LibraryFlag) async throws {
        try await callOptionalVoidMethod(method: "onContentsReadingFlagChanged", arguments: [ids, flag.rawValue])
    }

    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async throws {
        try await callOptionalVoidMethod(method: "onChaptersMarked", arguments: [contentId, chapterIds, completed])
    }

    func onChapterRead(contentId: String, chapterId: String) async throws {
        try await callOptionalVoidMethod(method: "onChapterRead", arguments: [contentId, chapterId])
    }

    func syncUserLibrary(library: [DSKCommon.UpSyncedContent]) async throws -> [DSKCommon.DownSyncedContent] {
        let method = "syncUserLibrary"
        if !methodExists(method: method) {
            throw DSK.Errors.MethodNotImplemented
        }
        let data = try DaisukeEngine.encode(value: library)
        let library = try JSONSerialization.jsonObject(with: data)
        return try await callMethodReturningDecodable(method: method, arguments: [library], resolvesTo: [DSKCommon.DownSyncedContent].self)
    }

    func getReadChapterMarkers(contentId: String) async throws -> [String] {
        let methodName = "getReadChapterMarkers"
        guard methodExists(method: methodName) else {
            throw DSK.Errors.MethodNotImplemented
        }
        return try await callMethodReturningDecodable(method: methodName, arguments: [contentId], resolvesTo: [String].self)
    }
}
