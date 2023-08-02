//
//  Data+TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import Foundation
import RealmSwift

extension DataManager {
    func setTrackerLink(for id: String, values: [String: String]) {
        let realm = try! Realm()

        let target = realm
            .objects(TrackerLink.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        if let target {
            try! realm.safeWrite {
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
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func removeLinkKey(for id: String, key: String) {
        let realm = try! Realm()

        let target = realm
            .objects(TrackerLink.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        guard let target else {
            return
        }
        let pctEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!

        try! realm.safeWrite {
            target.data.removeObject(for: pctEncodedKey) // Realm Error when using not encoded https://github.com/realm/realm-swift/issues/8290
        }
    }

    func getLinkKeys(for id: String) -> [String: String] {
        let content = DataManager.shared.getStoredContent(id)
        guard let content else { return [:] }
        let linked = DataManager.shared.getLinkedContent(for: id)
        let targets = linked.map(\.id).appending(id)

        let realm = try! Realm()
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
}
