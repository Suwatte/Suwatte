//
//  DSK+CS+Events.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Foundation

extension DaisukeEngine.ContentSource {
    func onSourceLoaded() async {
        do {
            try await callOptionalVoidMethod(method: "onSourceLoaded", arguments: [])
        } catch {
            ToastManager.shared.setError(error: error)
        }
    }

    func onContentsAddedToLibrary(ids: [String]) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsAddedToLibrary", arguments: [ids])
        } catch {
            ToastManager.shared.setError(error: error)
        }
    }

    func onContentsRemovedFromLibrary(ids: [String]) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsRemovedFromLibrary", arguments: [ids])
        } catch {
            ToastManager.shared.setError(error: error)
        }
    }

    func onChaptersCompleted(contentId: String, chapterIds: [String]) async {
        do {
            try await callOptionalVoidMethod(method: "onChaptersCompleted", arguments: [contentId, chapterIds])
        } catch {
            ToastManager.shared.setError(error: error)
        }
    }

    func onContentsReadingFlagChanged(contentIds: [String], flag: LibraryFlag) async {
        do {
            try await callOptionalVoidMethod(method: "onContentsReadingFlagChanged", arguments: [contentIds, flag.rawValue])
        } catch {
            ToastManager.shared.setError(error: error)
        }
    }
}

extension DaisukeEngine.ContentSource {
    func willRequestImage(request : DaisukeEngine.NetworkClient.Request) async throws -> DaisukeEngine.NetworkClient.Request? {
        
        guard methodExists(method: "willRequestImage") else {
            return nil
        }
        let dict = try request.asDictionary()
        
        return try await callMethodReturningDecodable(method: "willRequestImage", arguments: [dict], resolvesTo: DaisukeEngine.NetworkClient.Request.self)
    }

    func willAttemptCloudflareVerification() async throws -> URL {
        throw DaisukeEngine.Errors.MethodNotImplemented
    }
}
