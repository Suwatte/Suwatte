//
//  Realm+CSSync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getUpSync(for id: String) -> [DSKCommon.UpSyncedContent] {
        let library: [DSKCommon.UpSyncedContent] = realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == id }
            .where { $0.content != nil }
            .map { .init(id: $0.content!.contentId, flag: $0.flag) }
        return library
    }
}

extension RealmActor {
    func downSyncLibrary(entries: [DSKCommon.DownSyncedContent], sourceId: String) async {
        await operation {
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
