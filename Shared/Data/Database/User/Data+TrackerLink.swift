//
//  Data+TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import Foundation
import RealmSwift

extension DataManager {
    func linkContentToTracker(id: String, al: String? = nil, kt: String? = nil, mal: String? = nil) {
        let realm = try! Realm()

        if let tracker = realm.objects(TrackerLink.self).first(where: { $0.id == id && $0.isDeleted == false  }) {
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

            obj.id = id
            let info = StoredTrackerInfo()
            info.al = al
            info.mal = mal
            info.kt = kt

            obj.trackerInfo = info

            try! realm.safeWrite {
                realm.add(obj, update: .modified)
            }
        }
    }

    func unlinkContentToTracker(_ obj: TrackerLink) {
        guard let obj = obj.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            obj.isDeleted = true
        }
    }

    func getTrackerInfo(_ id: String) -> StoredTrackerInfo? {
        let realm = try! Realm()

        return realm.objects(TrackerLink.self).first(where: { $0.id == id && $0.isDeleted == false })?.trackerInfo
    }
}
