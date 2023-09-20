//
//  Realm+ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func saveChapterData(data: DSKCommon.ChapterData, chapter: ThreadSafeChapter) async {
        let stored = data.toStored(withStoredChapter: chapter.toStored())
        await operation {
            realm.add(stored, update: .modified)
        }
    }

    func getChapterData(forId id: String) -> StoredChapterData? {
        return realm.object(ofType: StoredChapterData.self, forPrimaryKey: id)?.freeze()
    }

    func resetChapterData(forId id: String) async {
        let target = realm.objects(StoredChapterData.self).first(where: { $0._id == id })

        guard let target else { return }
        await operation {
            realm.delete(target)
        }
    }

    func resetChapterData(for ids: [String]) async {
        let targets = realm
            .objects(StoredChapterData.self)
            .where { $0._id.in(ids) }

        await operation {
            realm.delete(targets)
        }
    }
}
