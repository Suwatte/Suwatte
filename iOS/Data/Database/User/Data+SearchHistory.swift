//
//  Data+SearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import Foundation
import RealmSwift

extension DataManager {
    func saveSearch(_ request: DSKCommon.DirectoryRequest, sourceId: String?, display: String) throws {
        let incognito = Preferences.standard.incognitoMode
        if incognito { return }

        let realm = try! Realm()

        let data = try DSK.stringify(request)
        let obj = UpdatedSearchHistory()
        obj.data = data
        obj.displayText = display
        obj.sourceId = sourceId
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func deleteSearch(_ object: UpdatedSearchHistory) {
        guard let object = object.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            object.isDeleted = true
        }
    }
}

extension DataManager {
    func getSearchHistory(for sourceId: String) -> [UpdatedSearchHistory] {
        let realm = try! Realm()

        return realm.objects(UpdatedSearchHistory.self).filter { $0.sourceId == sourceId }
    }

    // No Source ID means it was an all source search
    func getAllSearchHistory() -> [UpdatedSearchHistory] {
        let realm = try! Realm()

        return realm.objects(UpdatedSearchHistory.self).filter { $0.sourceId == nil }
    }
}

extension DataManager {
    func deleteSearchHistory(for sourceId: String) {
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.objects(UpdatedSearchHistory.self).where { $0.sourceId == sourceId }.forEach { obj in
                obj.isDeleted = true
            }
        }
    }
}
