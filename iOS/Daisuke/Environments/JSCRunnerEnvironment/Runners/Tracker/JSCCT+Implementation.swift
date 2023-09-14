//
//  JSCCT+Implementation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import Foundation

extension JSCContentTracker: ContentTracker {
    /// Returns the form to present to the user to update the entry form.
    func getEntryForm(id: String) async throws -> DSKCommon.Form {
        try await callMethodReturningDecodable(method: "getEntryForm", arguments: [id], resolvesTo: DSKCommon.Form.self)
    }

    /// Called when the user submits the entry form
    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws {
        let object = try form.asDictionary()
        try await callOptionalVoidMethod(method: "didSubmitEntryForm", arguments: [id, object])
    }

    /// Called to an item in the trackers database,
    func getTrackItem(id: String) async throws -> DSKCommon.Highlight {
        try await callMethodReturningDecodable(method: "getTrackItem", arguments: [id], resolvesTo: DSKCommon.Highlight.self)
    }

    /// Called to update an entries progress.
    func didUpdateLastReadChapter(id: String, progress: DSKCommon.TrackProgressUpdate) async throws {
        let object = try progress.asDictionary()
        try await callOptionalVoidMethod(method: "didUpdateLastReadChapter", arguments: [id, object])
    }

    func getResultsForTitles(titles: [String]) async throws -> [DSKCommon.Highlight] {
        try await callMethodReturningDecodable(method: "getResultsForTitles", arguments: [titles], resolvesTo: [DSKCommon.Highlight].self)
    }

    // Called to begin tracking an entry
    func beginTracking(id: String, status: DSKCommon.TrackStatus) async throws {
        try await callOptionalVoidMethod(method: "beginTracking", arguments: [id, status.rawValue])
    }

    // Called to update the status of an entry
    func didUpdateStatus(id: String, status: DSKCommon.TrackStatus) async throws {
        try await callOptionalVoidMethod(method: "didUpdateStatus", arguments: [id, status.rawValue])
    }

    func getFullInformation(id: String) async throws -> DSKCommon.FullTrackItem {
        try await callMethodReturningDecodable(method: "getFullInformation", arguments: [id], resolvesTo: DSKCommon.FullTrackItem.self)
    }

    func toggleFavorite(state: Bool) async throws {
        try await callOptionalVoidMethod(method: "toggleFavorite", arguments: [state])
    }
}
