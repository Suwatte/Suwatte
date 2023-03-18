//
//  Data+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-21.
//

import Foundation
import RealmSwift

final class ContentLink : Object, Identifiable {
    @Persisted(primaryKey: true) var id = UUID().uuidString
    @Persisted var ids: MutableSet<String>
}

extension DataManager {
    func linkContent(_ parent: StoredContent, _ child: DSKCommon.Highlight, _ sourceId: String) -> Bool {
        let id = ContentIdentifier(contentId: child.contentId, sourceId: sourceId).id
        saveIfNeeded(child, sourceId)
        return linkContent(parent._id, id)
    }

    func linkContent(_ one: String, _ two: String) -> Bool {
        let realm = try! Realm()

        let matches = !realm
            .objects(ContentLink.self)
            .where { $0.ids.contains(one) && $0.ids.contains(two) }
            .isEmpty

        if matches {
            return false
        }
        
        let target = realm
            .objects(ContentLink.self)
            .where({ $0.ids.containsAny(in: [one, two]) })
            .first
        
        // A or B already in a linkset
        if let target {
            try! realm.safeWrite {
                target.ids.insert(one)
                target.ids.insert(two)
            }
        } else {
            let obj = ContentLink()
            obj.ids.insert(one)
            obj.ids.insert(two)
            try! realm.safeWrite {
                realm.add(obj)
            }
        }
        return true
    }

    func unlinkContent(_ child: StoredContent, _ from: StoredContent) {
        let realm = try! Realm()
        
        let target = realm
            .objects(ContentLink.self)
            .where({ $0.ids.containsAny(in: [child._id, from._id]) })
            .first
        
        guard let target else {
            return
        }
        try! realm.safeWrite {
            target.ids.remove(child._id)
        }
    }

    func getLinkedContent(for id: String) -> [StoredContent] {
        let realm = try! Realm()
        var ids = realm
            .objects(ContentLink.self)
            .where { $0.ids.contains(id) }
            .first?
            .ids
            
        

        guard let ids else {
            return []
        }
        
        var arr = Array(ids)
        arr.removeAll(where: { $0 == id })
        let contents = Array(getStoredContents(ids: arr))
        
        return contents
    }

    func getPossibleTrackerInfo(for id: String) throws -> [String: String?]? {
        let linked = getLinkedContent(for: id)

        // Search Embeded Linked Content First for Tracker Info
        let linkedEmbeddedFound = linked.first(where: { !$0.trackerInfo.values.isEmpty })?.trackerInfo

        if let linkedEmbeddedFound {
            return try linkedEmbeddedFound.asDictionary() as? [String: String]
        }

        // Check For Stored Tracker Links

        let ids = linked.map(\._id)

        let realm = try! Realm()

        let match = realm
            .objects(TrackerLink.self)
            .where { $0._id.in(ids) }
            .first?
            .trackerInfo

        guard let match else { return nil }

        return [
            "al": match.al,
            "mal": match.mal,
            "kt": match.kt,
            "mu": match.mu,
        ]
    }
    
    func saveIfNeeded(_ h: DSKCommon.Highlight, _ sId: String) {
        let realm = try! Realm()
        
        let result = realm
            .objects(StoredContent.self)
            .where({ $0.sourceId ==  sId && $0.contentId == h.contentId })
        guard result.isEmpty  else {
            return
        }
        
        let obj = h.toStored(sourceId: sId)
        try! realm.safeWrite {
            realm.add(obj)
        }
    }
}

extension DSKCommon.Highlight {
    func toStored(sourceId: String) -> StoredContent {
        let stored = StoredContent()
        stored.title = title
        stored.contentId = contentId
        stored.sourceId = sourceId
        stored.cover = cover

        return stored
    }
}
