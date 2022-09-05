//
//  Data+TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import Foundation
import RealmSwift

final class TrackerLink: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: String
    @Persisted var trackerInfo: StoredTrackerInfo?
}

extension DataManager {
    func linkContentToTracker(id: String, al: String? = nil, kt: String? = nil, mal: String? = nil) {
        let realm = try! Realm()

        if let tracker = realm.objects(TrackerLink.self).first(where: { $0._id == id }) {
            try! realm.safeWrite {
                if let al = al {
                    tracker.trackerInfo?.al = al
                }

                if let mal = mal {
                    tracker.trackerInfo?.mal = mal
                }

                if let kt = kt {
                    tracker.trackerInfo?.kt = kt
                }
            }
        } else {
            let obj = TrackerLink()

            obj._id = id
            let info = StoredTrackerInfo()
            info.al = al
            info.mal = mal
            info.kt = kt

            obj.trackerInfo = info

            try! realm.safeWrite {
                realm.add(obj)
            }
        }
    }

    func unlinkContentToTracker(_ obj: TrackerLink) {
        guard let obj = obj.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.delete(obj)
        }
    }

    func getTrackerInfo(_ id: String) -> StoredTrackerInfo? {
        let realm = try! Realm()

        return realm.objects(TrackerLink.self).first(where: { $0._id == id })?.trackerInfo
    }
}
