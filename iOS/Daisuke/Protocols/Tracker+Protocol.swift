//
//  Tracker+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

struct TrackerConfig: Parsable {
    let linkKeys: [String]?
}

protocol ContentTracker: DSKRunner {
    var config: TrackerConfig? { get }

    func getEntryForm(id: String) async throws -> DSKCommon.Form

    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws

    func getTrackItem(id: String) async throws -> DSKCommon.Highlight

    func didUpdateLastReadChapter(id: String, progress: DSKCommon.TrackProgressUpdate) async throws

    func getResultsForTitles(titles: [String]) async throws -> [DSKCommon.Highlight]

    func beginTracking(id: String, status: DSKCommon.TrackStatus) async throws

    func didUpdateStatus(id: String, status: DSKCommon.TrackStatus) async throws

    func getFullInformation(id: String) async throws -> DSKCommon.FullTrackItem

    func toggleFavorite(state: Bool) async throws
}

extension ContentTracker {
    var links: [String] {
        let def = config?.linkKeys ?? []
        return def.appending(id)
    }
}

typealias AnyContentTracker = (any ContentTracker)
