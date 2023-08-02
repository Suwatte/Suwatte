//
//  Data+StoredChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import Foundation
import RealmSwift



extension DataManager {
    func saveChapterData(chapter: StoredChapter, data: DaisukeEngine.Structs.ChapterData) {
        guard let chapter = chapter.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.add(data.toStored(withStoredChapter: chapter), update: .all)
        }
    }

    func saveChapterData(data: StoredChapterData) {
        let realm = try! Realm()
        try! realm.safeWrite {
            let chapter = data.chapter
            data.chapter = chapter
            realm.add(data, update: .all)
        }
    }

    func getChapterData(forId id: String) -> StoredChapterData? {
        let realm = try! Realm()
        return realm.objects(StoredChapterData.self).first { $0._id == id }
    }

    func resetChapterData(forId id: String) {
        let realm = try! Realm()

        let target = realm.objects(StoredChapterData.self).first(where: { $0._id == id })

        if let target = target {
            try! realm.safeWrite {
                realm.delete(target)
            }
        }
    }
}
