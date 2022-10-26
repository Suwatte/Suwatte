//
//  DSK+CS+Events.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation

extension DaisukeEngine.LocalContentSource {
    func onSourceLoaded() async {
        do {
            try await callOptionalVoidMethod(method: "onSourceLoaded", arguments: [])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onSourceLoaded] \(error.localizedDescription)"))
        }
    }

    func onContentsAddedToLibrary(ids: [String]) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsAddedToLibrary", arguments: [ids])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onContentsAddedToLibrary] \(error.localizedDescription)"))
        }
    }

    func onContentsRemovedFromLibrary(ids: [String]) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsRemovedFromLibrary", arguments: [ids])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onContentsRemovedFromLibrary] \(error.localizedDescription)"))
        }
    }

    func onChaptersMarked(contentId: String, chapterIds: [String], completed: Bool) async {
        do {
            try await callOptionalVoidMethod(method: "onChaptersMarked", arguments: [contentId, chapterIds, completed])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onChaptersMarked] \(error.localizedDescription)"))
        }
    }

    func onChapterRead(contentId: String, chapterId: String) async {
        do {
            try await callOptionalVoidMethod(method: "onChapterRead", arguments: [contentId, chapterId])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onChapterRead] \(error.localizedDescription)"))
        }
    }

    func onContentsReadingFlagChanged(contentIds: [String], flag: LibraryFlag) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsReadingFlagChanged", arguments: [contentIds, flag.rawValue])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [onContentsReadingFlagChanged] \(error.localizedDescription)"))
        }
    }
}

extension DaisukeEngine.LocalContentSource {
    func willRequestImage(request: DaisukeEngine.NetworkClient.Request) async throws -> DaisukeEngine.NetworkClient.Request? {
        guard methodExists(method: "willRequestImage") else {
            return nil
        }
        let dict = try request.asDictionary()

        return try await callMethodReturningDecodable(method: "willRequestImage", arguments: [dict], resolvesTo: DaisukeEngine.NetworkClient.Request.self)
    }

    func willAttemptCloudflareVerification() async throws -> DSKCommon.Request {
        try await callMethodReturningDecodable(method: "willAttemptCloudflareVerification", arguments: [], resolvesTo: DSKCommon.Request.self)
    }
}
