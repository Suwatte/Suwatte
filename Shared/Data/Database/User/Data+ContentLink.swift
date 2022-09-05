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
    func linkContent(parent: StoredContent, child: StoredContent) -> Bool {
        let realm = try! Realm()

        if !realm.objects(ContentLink.self).filter({ ($0.parent?._id == parent._id && $0.child?._id == child._id) || ($0.parent?._id == child._id && $0.child?._id == parent._id) }).isEmpty {
            return false
        }

        let obj = ContentLink()
        obj.parent = parent
        obj.child = child

        try! realm.safeWrite {
            realm.add(obj)
        }

        return true
    }

    func unlinkContent(_: StoredContent, from _: StoredContent) {}
}
