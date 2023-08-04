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


protocol ContentTracker : DSKRunner {
    var config: TrackerConfig? { get }

    func getEntryForm(id: String) async throws -> DSKCommon.TrackForm

    func didSubmitEntryForm(id: String, form: DSKCommon.CodableDict) async throws

    func getTrackItem(id: String) async throws -> DSKCommon.TrackItem

    func didUpdateLastReadChapter(id: String, progress: DSKCommon.TrackProgressUpdate) async throws

    func getResultsForTitles(titles: [String]) async throws -> [DSKCommon.TrackItem]

    func beginTracking(id: String, status: DSKCommon.TrackStatus) async throws

    func stopTracking(id: String) async throws

    func didUpdateStatus(id: String, status: DSKCommon.TrackStatus) async throws
}

extension ContentTracker {
    var links: [String] {
        let def = config?.linkKeys ?? []
        return def.appending(id)
    }
}

typealias AnyContentTracker = (any ContentTracker)
typealias JSCCT = (any ContentTracker)
