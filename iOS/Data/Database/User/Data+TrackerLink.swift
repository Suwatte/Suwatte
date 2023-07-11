//
//  Data+TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import Foundation
import RealmSwift


extension DataManager {
    

    
    func setTrackerLink(for id: String, key: String,  value: String) {
        let realm = try! Realm()
        
        let target = realm
            .objects(TrackerLink.self)
            .where { $0.id == id && !$0.isDeleted }
            .first
        
        if let target {
            try! realm.safeWrite {
                target.setValue(value, forKey: key)
            }
            return
        }
        
        let obj = TrackerLink()
        obj.id = id
        obj.setValue(value, forKey: key)
        try! realm.safeWrite {
            realm.add(obj,update: .modified)
        }
    }
    
    func getTrackerLinks(for id: String) -> [String:String] {
        let content = DataManager.shared.getStoredContent(id)
        guard let content else { return [:] }
        let linked = DataManager.shared.getLinkedContent(for: id)
        let targets = linked.map(\.id).appending(id)
        
        let realm = try! Realm()
        let trackerLinkData =  realm
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
            
        for (key, value) in contentTrackerData  {
            dict[key] = value
        }
        
        var matches : Dictionary<String, String> = [:]
        
        for (key, value) in dict {
            let trackers = DSK
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
    
    func updateTrackProgress(`for` id: String, `progress`: DSKCommon.TrackProgressUpdate) {
        let links = getTrackerLinks(for: id)
        
        for (trackerId, mediaId) in links {
            guard let tracker = DSK.shared.getTracker(id: trackerId) else { continue }
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
