//
//  Data+SearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import Foundation
import RealmSwift

final class UpdatedSearchHistory: Object, ObjectKeyIdentifiable, Codable {
    @Persisted var sourceId: String?
    @Persisted var data: String // JSON String of SearchREquest
    @Persisted var displayText: String
    @Persisted var date: Date = .now
    @Persisted(primaryKey: true) var _id: ObjectId
}

extension DataManager {
    func saveSearch(_ request: DSKCommon.SearchRequest, sourceId: String?, display: String) throws {
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
            realm.delete(object)
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
            realm.delete(realm.objects(UpdatedSearchHistory.self).where { $0.sourceId == sourceId })
        }
    }
}
