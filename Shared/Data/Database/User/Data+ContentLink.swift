//
//  Data+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-21.
//

import Foundation
import RealmSwift

class ContentLink: Object, Identifiable {
    @Persisted(primaryKey: true) var id = UUID().uuidString
    @Persisted var parent: StoredContent?
    @Persisted var child: StoredContent?
}

extension DataManager {
    
    func linkContent(_ parent: StoredContent, _ child: DSKCommon.Highlight,_ sourceId: String ) -> Bool {
        let childStored = child.toStored(sourceId: sourceId)
        return linkContent(parent, childStored)
    }
    func linkContent(_ parent: StoredContent,_  child: StoredContent) -> Bool {
        let realm = try! Realm()
        
        let matches = !realm
            .objects(ContentLink.self)
            .where({ $0.parent._id == parent._id ||  $0.child._id == parent._id })
            .where({ $0.parent._id == child._id ||  $0.child._id == child._id })
            .isEmpty

        if matches {
            return false
        }

        let obj = ContentLink()
        obj.parent = parent
        obj.child = child

        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }

        return true
    }

    func unlinkContent(_ child: StoredContent, _ from: StoredContent) {
        let realm = try! Realm()
        
        let matches = realm
            .objects(ContentLink.self)
            .where({ $0.parent._id == from._id ||  $0.child._id == from._id })
            .where({ $0.parent._id == child._id ||  $0.child._id == child._id })
        
        try! realm.safeWrite {
            realm.delete(matches)
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
