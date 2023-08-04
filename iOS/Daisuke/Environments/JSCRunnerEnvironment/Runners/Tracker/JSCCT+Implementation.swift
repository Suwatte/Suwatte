//
//  JSCCT+Implementation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation

extension JSCContentTracker: ContentTracker {
    /// Returns the form to present to the user to update the entry form.
    func getEntryForm(id: String) async throws -> DSKCommon.TrackForm {
        try await callMethodReturningDecodable(method: "getEntryForm", arguments: [id], resolvesTo: DSKCommon.TrackForm.self)
    }

    /// Called when the user submits the entry form
    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws {
        let object = try form.asDictionary()
        try await callOptionalVoidMethod(method: "didSubmitEntryForm", arguments: [id, object])
    }

    /// Called to an item in the trackers database,
    func getTrackItem(id: String) async throws -> DSKCommon.TrackItem {
        try await callMethodReturningDecodable(method: "getTrackItem", arguments: [id], resolvesTo: DSKCommon.TrackItem.self)
    }

    /// Called to update an entries progress.
    func didUpdateLastReadChapter(id: String, progress: DSKCommon.TrackProgressUpdate) async throws {
        let object = try progress.asDictionary()
        try await callOptionalVoidMethod(method: "didUpdateLastReadChapter", arguments: [id, object])
    }

    func getResultsForTitles(titles: [String]) async throws -> [DSKCommon.TrackItem] {
        try await callMethodReturningDecodable(method: "getResultsForTitles", arguments: [titles], resolvesTo: [DSKCommon.TrackItem].self)
    }

    // Called to begin tracking an entry
    func beginTracking(id: String, status: DSKCommon.TrackStatus) async throws {
        try await callOptionalVoidMethod(method: "beginTracking", arguments: [id, status.rawValue])
    }

    // Called to stop tracking an entry
    func stopTracking(id: String) async throws {
        try await callOptionalVoidMethod(method: "stopTracking", arguments: [id])
    }

    // Called to update the status of an entry
    func didUpdateStatus(id: String, status: DSKCommon.TrackStatus) async throws {
        try await callOptionalVoidMethod(method: "didUpdateStatus", arguments: [id, status.rawValue])
    }
}
