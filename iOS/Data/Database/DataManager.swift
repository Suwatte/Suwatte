//
//  DataManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-04.
//

import Foundation
import RealmSwift

class DataManager {
    static var shared = DataManager()
}

extension DataManager {
    func downSyncLibrary(entries: [DSKCommon.DownSyncedContent], sourceId: String) {
        let realm = try! Realm()

        try! realm.safeWrite {
            for entry in entries {
                let libraryTarget = realm.objects(LibraryEntry.self)
                    .where { $0.content.contentId == entry.id }
                    .where { $0.content.sourceId == sourceId }
                    .first

                // Title, In Library, Update Flag
                if let libraryTarget, let flag = entry.readingFlag {
                    libraryTarget.flag = flag
                    continue
                }

                // Not In Library, Find/Create Stored then save
                var currentStored = realm
                    .objects(StoredContent.self)
                    .where { $0.contentId == entry.id }
                    .where { $0.sourceId == sourceId }
                    .first
                if currentStored == nil {
                    currentStored = StoredContent()
                    currentStored?.id = "\(sourceId)||\(entry.id)"
                    currentStored?.contentId = entry.id
                    currentStored?.sourceId = sourceId
                    currentStored?.title = entry.title
                    currentStored?.cover = entry.cover
                }
                guard let currentStored = currentStored else {
                    return
                }

                realm.add(currentStored, update: .modified)
                let libraryObject = LibraryEntry()
                libraryObject.content = currentStored
                if let flag = entry.readingFlag {
                    libraryObject.flag = flag
                }
                realm.add(libraryObject)
            }
        }
    }
}
