//
//  Realm+Search.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//


import Foundation
import RealmSwift

extension RealmActor {
    func saveSearch(_ request: DSKCommon.DirectoryRequest, sourceId: String?, display: String) async {
        let incognito = Preferences.standard.incognitoMode
        if incognito { return }
        do {
            let data = try DSK.stringify(request)
            let obj = UpdatedSearchHistory()
            obj.data = data
            obj.displayText = display
            obj.sourceId = sourceId
            try! await realm.asyncWrite {
                realm.add(obj, update: .modified)
            }
        } catch {
            Logger.shared.error(error, "RealmActor")
        }
    }

    func deleteSearch(_ object: UpdatedSearchHistory) async {
        guard let object = object.thaw() else {
            return
        }
        try! await realm.asyncWrite {
            object.isDeleted = true
        }
    }
}

extension RealmActor {
    func getSearchHistory(for sourceId: String) -> [UpdatedSearchHistory] {

        return realm.objects(UpdatedSearchHistory.self).filter { $0.sourceId == sourceId }
    }

    // No Source ID means it was an all source search
    func getAllSearchHistory() -> [UpdatedSearchHistory] {

        return realm.objects(UpdatedSearchHistory.self).filter { $0.sourceId == nil }
    }
}

extension RealmActor {
    func deleteSearchHistory(for sourceId: String) async {

        try! await realm.asyncWrite {
            realm.objects(UpdatedSearchHistory.self).where { $0.sourceId == sourceId }.forEach { obj in
                obj.isDeleted = true
            }
        }
    }
}
