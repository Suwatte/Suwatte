//
//  Realm+TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func setTrackerLink(for id: String, values: [String: String]) async {
        let target = realm
            .objects(TrackerLink.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        if let target {
            try! await realm.asyncWrite {
                values.forEach { key, value in
                    let pctEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                    target.data.updateValue(value, forKey: pctEncodedKey)
                }
            }
            return
        }

        let obj = TrackerLink()
        obj.id = id
        values.forEach { key, value in
            let pctEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            obj.data.updateValue(value, forKey: pctEncodedKey)
        }
        try! await realm.asyncWrite {
            realm.add(obj, update: .modified)
        }
    }

    func removeLinkKey(for id: String, key: String) async {
        let target = realm
            .objects(TrackerLink.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        guard let target else {
            return
        }
        let pctEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!

        try! await realm.asyncWrite {
            target.data.removeObject(for: pctEncodedKey) // Realm Error when using not encoded https://github.com/realm/realm-swift/issues/8290
        }
    }

    func getLinkKeys(for id: String) -> [String: String] {
        let content = getStoredContent(id)
        guard let content else { return [:] }
        let linked = getLinkedContent(for: id)
        let targets = linked.map(\.id).appending(id)

        let trackerLinkData = realm
            .objects(TrackerLink.self)
            .where { $0.id.in(targets) }
            .flatMap { $0.data.asKeyValueSequence() }

        // Add Values from TrackerLinks
        var dict: [String: String] = [:]
        for (key, value) in trackerLinkData {
            dict[key] = value
        }

        // Add Values from Stored Content
        let contentTrackerData = linked
            .appending(content)
            .flatMap { $0.trackerInfo.asKeyValueSequence() }

        for (key, value) in contentTrackerData {
            dict[key] = value
        }

        return dict.filter { !$0.value.isEmpty }
    }

    func getTrackerLinks(for id: String) async -> [String: String] {
        let dict = getLinkKeys(for: id)
        var matches: [String: String] = [:]

        for (key, value) in dict {
            let trackers = await DSK
                .shared
                .getActiveTrackers()
                .filter { $0.links.contains(key) }

            // Trackers that can handle this link
            for tracker in trackers {
                guard matches[tracker.id] == nil else { continue }
                matches[tracker.id] = value
            }
        }

        return matches
    }

    func updateTrackProgress(for id: String, progress: DSKCommon.TrackProgressUpdate) async {
        let links = await getTrackerLinks(for: id)

        for (trackerId, mediaId) in links {
            guard let tracker = await DSK.shared.getTracker(id: trackerId) else { continue }
            Task.detached {
                do {
                    try await tracker.didUpdateLastReadChapter(id: mediaId, progress: progress)
                } catch {
                    Logger.shared.error(error, trackerId)
                }
            }
        }
    }
}
