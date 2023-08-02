//
//  Realm+ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift
import Foundation

extension RealmActor {
    func saveChapterData(chapter: StoredChapter, data: DaisukeEngine.Structs.ChapterData) async {
        guard let chapter = chapter.thaw() else {
            return
        }
        try! await realm.asyncWrite {
            realm.add(data.toStored(withStoredChapter: chapter), update: .all)
        }
    }

    func saveChapterData(data: StoredChapterData) async {
        try! await realm.asyncWrite {
            let chapter = data.chapter
            data.chapter = chapter
            realm.add(data, update: .all)
        }
    }

    func getChapterData(forId id: String) -> StoredChapterData? {
        return realm
            .objects(StoredChapterData.self)
            .where { $0._id == id }
            .first?
            .freeze()
    }

    func resetChapterData(forId id: String) async {
        let target = realm.objects(StoredChapterData.self).first(where: { $0._id == id })

        guard let target else { return }
        try! await realm.asyncWrite {
            realm.delete(target)
        }
    }
    
    
    func resetChapterData(for ids: [String]) async {
        let targets = realm
            .objects(StoredChapterData.self)
            .where { $0._id.in(ids) }
        
        try! await realm.asyncWrite {
            realm.delete(targets)
        }
    }
}
