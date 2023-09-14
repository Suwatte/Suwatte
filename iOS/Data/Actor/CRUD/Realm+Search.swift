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
            await operation {
                realm.add(obj, update: .modified)
            }
        } catch {
            Logger.shared.error(error, "RealmActor")
        }
    }

    func deleteSearch(_ id: String) async {
        let target = realm
            .objects(UpdatedSearchHistory.self)
            .where { $0.id == id }
            .first

        guard let target else { return }
        await operation {
            target.isDeleted = true
        }
    }
}

extension RealmActor {
    func getSearchHistory(for sourceId: String) -> [UpdatedSearchHistory] {
        return realm
            .objects(UpdatedSearchHistory.self)
            .where { $0.sourceId == sourceId }
            .where { !$0.isDeleted }
            .freeze()
            .toArray()
    }

    // No Source ID means it was an all source search
    func getAllSearchHistory() -> [UpdatedSearchHistory] {
        return realm
            .objects(UpdatedSearchHistory.self)
            .where { $0.sourceId == nil }
            .where { !$0.isDeleted }
            .freeze()
            .toArray()
    }
}

extension RealmActor {
    func deleteSearchHistory(for sourceId: String) async {
        let objects = realm
            .objects(UpdatedSearchHistory.self)
            .where { $0.sourceId == sourceId }
            .where { !$0.isDeleted }

        await operation {
            for object in objects {
                object.isDeleted = true
            }
        }
    }

    func deleteSearchHistory() async {
        let objects = realm
            .objects(UpdatedSearchHistory.self)
            .where { $0.sourceId == nil }

        await operation {
            for object in objects {
                object.isDeleted = true
            }
        }
    }
}
