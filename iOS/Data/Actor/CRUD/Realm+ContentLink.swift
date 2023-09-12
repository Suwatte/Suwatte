//
//  Realm+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func linkContent(_ parent: String, _ child: DSKCommon.Highlight, _ sourceId: String) async -> Bool {
        let id = ContentIdentifier(contentId: child.id, sourceId: sourceId).id
        await saveIfNeeded(child, sourceId)
        return await linkContent(parent, id)
    }

    func linkContent(_ one: String, _ two: String) async -> Bool {
        let matches = !realm
            .objects(ContentLink.self)
            .where { $0.ids.contains(one) && $0.ids.contains(two) && $0.isDeleted == false }
            .isEmpty

        if matches {
            return false
        }

        let target = realm
            .objects(ContentLink.self)
            .where { $0.ids.containsAny(in: [one, two]) && $0.isDeleted == false }
            .first

        // A or B already in a linkset
        if let target {
            await operation {
                target.ids.insert(one)
                target.ids.insert(two)
            }
        } else {
            let obj = ContentLink()
            obj.ids.insert(one)
            obj.ids.insert(two)
            await operation {
                realm.add(obj, update: .modified)
            }
        }
        return true
    }

    func unlinkContent(_ child: String, _ from: String) async {
        let target = realm
            .objects(ContentLink.self)
            .where { $0.ids.containsAny(in: [child, from]) && $0.isDeleted == false }
            .first

        guard let target else {
            return
        }
        await operation {
            target.ids.remove(child)
        }
    }

    func getLinkedContent(for id: String, _ removeQuery: Bool = true) -> [StoredContent] {
        let ids = realm
            .objects(ContentLink.self)
            .where { $0.ids.contains(id) && $0.isDeleted == false }
            .first?
            .ids

        guard let ids else {
            return []
        }

        var arr = Array(ids)
        if removeQuery {
            arr.removeAll(where: { $0 == id })
        }
        let contents = getStoredContents(ids: arr)
            .freeze()
            .toArray()

        return contents
    }

    func saveIfNeeded(_ h: DSKCommon.Highlight, _ sId: String) async {
        let result = realm
            .objects(StoredContent.self)
            .where { $0.sourceId == sId && $0.contentId == h.id }
        guard result.isEmpty else {
            return
        }

        let obj = h.toStored(sourceId: sId)
        await operation {
            realm.add(obj)
        }
    }
}
