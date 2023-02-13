//
//  Data+SearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import Foundation
import RealmSwift

final class SearchHistory: Object, ObjectKeyIdentifiable, Codable {
    @Persisted var text: String?
    @Persisted var sourceId: String?
    @Persisted var included: List<String>
    @Persisted var excluded: List<String>
    @Persisted var date: Date
    @Persisted var label: String
}

extension DataManager {
    func saveSearch(_ text: String, sourceId: String?) {
        let incognito = Preferences.standard.incognitoMode
        if incognito { return }

        let realm = try! Realm()

        try! realm.safeWrite {
            let object = SearchHistory()
            object.sourceId = sourceId
            object.text = text
            object.date = Date()
            object.label = text
            realm.add(object)
        }
    }
    
    func deleteSearch(_ object: SearchHistory) {
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
    func getSearchHistory(for sourceId: String) -> [SearchHistory] {
        let realm = try! Realm()

        return realm.objects(SearchHistory.self).filter { $0.sourceId == sourceId }
    }

    // No Source ID means it was an all source search
    func getAllSearchHistory() -> [SearchHistory] {
        let realm = try! Realm()

        return realm.objects(SearchHistory.self).filter { $0.sourceId == nil }
    }
}

extension DataManager {
    func deleteSearchHistory(for sourceId: String) {
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.delete(realm.objects(SearchHistory.self).where { $0.sourceId == sourceId })
        }
    }
}
