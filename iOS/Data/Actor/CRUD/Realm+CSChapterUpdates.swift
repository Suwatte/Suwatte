//
//  Realm+CSChapterUpdates.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getTitlesPendingUpdate(_ sourceId: String) -> [LibraryEntry] {
        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        let skipConditions = Preferences.standard.skipConditions
        let validStatuses = [ContentStatus.ONGOING, .HIATUS, .UNKNOWN]
        var results = realm.objects(LibraryEntry.self)
            .where { $0.content != nil && $0.isDeleted == false }
            .where { $0.dateAdded < date }
            .where { $0.content.sourceId == sourceId }
            .where { $0.content.status.in(validStatuses) }

        // Flag Not Set to Reading Skip Condition
        if skipConditions.contains(.INVALID_FLAG) {
            results = results
                .where { $0.flag == .reading }
        }
        // Title Has Unread Skip Condition
        if skipConditions.contains(.HAS_UNREAD) {
            results = results
                .where { $0.unreadCount == 0 }
        }
        // Title Has No Markers, Has not been started
        if skipConditions.contains(.NO_MARKERS) {
            let ids = results.map(\.id) as [String]
            let startedTitles = realm
                .objects(ProgressMarker.self)
                .where { $0.id.in(ids) }
                .map(\.id) as [String]

            results = results
                .where { $0.id.in(startedTitles) }
        }
        let library = Array(results.freeze())
        return library
    }

    func didFindUpdates(for id: String, count: Int, date: Date, onLinked: Bool) async {
        let target = realm
            .objects(LibraryEntry.self)
            .where { $0.id == id }
            .first

        guard let target else { return }

        try! await realm.asyncWrite {
            target.lastUpdated = date
            target.updateCount += count
            if !target.linkedHasUpdates, onLinked {
                target.linkedHasUpdates = true
            }
        }
    }
}
