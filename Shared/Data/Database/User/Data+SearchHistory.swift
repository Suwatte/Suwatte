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

    func saveSearch(_ included: [String], _ excluded: [String], _ sourceId: String, _ filters: [DaisukeEngine.Structs.Filter]) {
        let incognito = Preferences.standard.incognitoMode
        if incognito { return }

        let tags = filters.flatMap { $0.property.tags }
        let includedLabels = tags.filter { included.contains($0.id) }.map { $0.label }
        let excludedLabels = tags.filter { excluded.contains($0.id) }.map { $0.label }

        let realm = try! Realm()

        try! realm.safeWrite {
            let object = SearchHistory()
            object.included.append(objectsIn: included)
            object.excluded.append(objectsIn: excluded)
            object.sourceId = sourceId

            var label = ""

            if !includedLabels.isEmpty {
                label += "Including Tags: \(includedLabels.joined(separator: ", "))"
            }

            if !includedLabels.isEmpty, !excludedLabels.isEmpty {
                label += "\n"
            }

            if !excludedLabels.isEmpty {
                label += "Exluding Tags: \(excludedLabels.joined(separator: ", "))"
            }

            object.label = label
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
