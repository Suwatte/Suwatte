//
//  WKT+Impl.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation

extension WKTracker: ContentTracker {
    func getEntryForm(id: String) async throws -> DSKCommon.Form {
        try await eval(script("let data = await RunnerObject.getEntryForm(id);"), ["id": id])
    }

    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws {
        try await eval("await RunnerObject.didSubmitEntryForm(id, form);", ["id": id, "form": form.asDictionary()])
    }

    func getTrackItem(id: String) async throws -> DSKCommon.TrackItem {
        try await eval(script("let data = await RunnerObject.getTrackItem(id);"), ["id": id])
    }

    func didUpdateLastReadChapter(id: String, progress: DSKCommon.TrackProgressUpdate) async throws {
        try await eval("await RunnerObject.didUpdateLastReadChapter(id, progress);", ["id": id, "progress": progress.asDictionary()])
    }

    func getResultsForTitles(titles: [String]) async throws -> [DSKCommon.TrackItem] {
        try await eval(script("let data = await RunnerObject.getResultsForTitles(titles);"), ["titles": titles])
    }

    func beginTracking(id: String, status: DSKCommon.TrackStatus) async throws {
        try await eval("await RunnerObject.beginTracking(id, status);", ["id": id, "status": status.rawValue])
    }

    func stopTracking(id: String) async throws {
        try await eval("await RunnerObject.stopTracking(id);", ["id": id])
    }

    func didUpdateStatus(id: String, status: DSKCommon.TrackStatus) async throws {
        try await eval("await RunnerObject.didUpdateStatus(id, status);", ["id": id, "status": status.rawValue])
    }

    func getFullInformation(id: String) async throws -> DSKCommon.FullTrackItem {
        try await eval(script("let data = await RunnerObject.getFullInformation(id);"),
                       ["id": id])
    }

    func toggleFavorite(state: Bool) async throws {
        try await eval("await RunnerObject.toggleFavorite(state);", ["state": state])
    }
}
