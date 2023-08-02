//
//  ReadLater.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//
import Foundation
import RealmSwift

extension DataManager {
    func toggleReadLater(_ source: String, _ content: String) {
        let id = ContentIdentifier(contentId: content, sourceId: source).id
        let realm = try! Realm()
        if let obj = realm.objects(ReadLater.self).first(where: { $0.id == id && $0.isDeleted == false }) {
            try! realm.safeWrite {
                obj.isDeleted = true
            }
            return
        }

    }

    func removeFromReadLater(_ source: String, content: String) {
        let realm = try! Realm()

        guard let obj = realm.objects(ReadLater.self).first(where: { $0.content?.contentId == content && $0.content?.sourceId == source && $0.isDeleted == false }) else {
            return
        }

        try! realm.safeWrite {
            obj.isDeleted = true
        }
    }

}
