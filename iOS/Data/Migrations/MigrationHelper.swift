//
//  Migration.swift
//  Suwatte (iOS)
//
//  Created by Seyden on 02.05.24.
//

import Foundation
import RealmSwift

class MigrationHelper {
    static func migrateContentLinks(migration: Migration) {
        migration.enumerateObjects(ofType: ContentLink.className()) { oldContentLinkObject, newContentLinkObject in
            guard let oldContentLinkObject = oldContentLinkObject else { return }

            let isDeleted = oldContentLinkObject["isDeleted"] as! Bool
            if isDeleted { return }

            var ids = Set(oldContentLinkObject["ids"] as! RealmSwift.MutableSet<String>)

            migration.enumerateObjects(ofType: LibraryEntry.className()) { _, libraryEntryObject in
                guard let libraryEntryObject else { return }
                if let libraryEntryId = libraryEntryObject["id"] as? String {

                    if ids.remove(libraryEntryId) != nil {

                        ids.forEach { linkContentId in
                            let newLink = migration.create(ContentLink.className())
                            newLink["id"] = "\(libraryEntryId)||\(linkContentId)"
                            newLink["entry"] = libraryEntryObject

                            migration.enumerateObjects(ofType: StoredContent.className()) { _, contentObject in
                                guard let contentObject else { return }
                                if let contentId = contentObject["id"] as? String {
                                    if contentId == linkContentId {
                                        newLink["content"] = contentObject
                                    }
                                }
                            }
                        }

                        migration.delete(newContentLinkObject!)
                    }
                }
            }
        }
    }
    static func migrateProgressMarker(realm: Realm) {
        let progressMarkers = realm.objects(ProgressMarker.self).where { !$0.isDeleted && $0.readChapters.count > 0 }
        for progressMarker in progressMarkers {
            let contentId = progressMarker.id

            let dateRead = progressMarker.dateRead

            var migrated = false

            let readChapters = progressMarker.readChapters
            readChapterLoop: for readChapter in readChapters {
                let storedChapters = realm.objects(StoredChapter.self).where { $0.id.starts(with: contentId, options: []) }
                storedChapterLoop: for storedChapter in storedChapters {
                    let chapterOrderKey = ThreadSafeChapter.orderKey(volume: readChapter < 10000 ? 0 : storedChapter["volume"] as? Double, number: storedChapter["number"] as! Double)

                    if chapterOrderKey == readChapter {
                        let chapterReference = ChapterReference()
                        chapterReference.id = storedChapter.id
                        chapterReference.chapterId = storedChapter.chapterId
                        chapterReference.number = storedChapter.number
                        chapterReference.volume = storedChapter.volume == 0.0 ? nil : storedChapter.volume
                        chapterReference.content = realm.object(ofType: StoredContent.self, forPrimaryKey: contentId)

                        let newProgressMarker = ProgressMarker()
                        newProgressMarker.id = storedChapter.id
                        newProgressMarker.chapter = chapterReference
                        newProgressMarker.totalPageCount = 1
                        newProgressMarker.lastPageRead = 1
                        newProgressMarker.lastPageOffsetPCT = nil
                        newProgressMarker.dateRead = dateRead

                        do {
                            try realm.write {
                                realm.add(newProgressMarker, update: .all)
                            }
                        } catch {
                            Logger.shared.error(error, "RealmActor")
                        }

                        migrated = true
                        break storedChapterLoop
                    }
                }

                if migrated {
                    do {
                        try realm.write {
                            progressMarker.readChapters.removeAll()
                            progressMarker.isDeleted = true
                        }
                    } catch {
                        Logger.shared.error(error, "RealmActor")
                    }

                }
            }
        }
    }

    static let interactorStoreObjectTypeName: String = "InteractorStoreObject"

    static func migrateInteractorStoreObjects(migration: Migration) {
        let userDefaultKey = "InteractorStoreObjects"
        var interactorStoreObjects = UserDefaults.standard.dictionary(forKey: userDefaultKey) as? [String: String] ?? [:]
        let countBeforeMigration = interactorStoreObjects.count

        migration.enumerateObjects(ofType: interactorStoreObjectTypeName) { oldInteractorStoreObject, _ in
            guard let oldInteractorStoreObject = oldInteractorStoreObject else { return }

            let id = oldInteractorStoreObject["id"] as! String
            let value = oldInteractorStoreObject["value"] as! String

            interactorStoreObjects[id] = value
        }

        if interactorStoreObjects.count > countBeforeMigration {
            UserDefaults.standard.set(interactorStoreObjects, forKey: userDefaultKey)
            migration.deleteData(forType: "InteractorStoreObject")
        }
    }

    static func migrationCheck(realm: Realm) {
        let schema = realm.schema[interactorStoreObjectTypeName]
        if schema != nil {
            let interactorStoreObjects = realm.dynamicObjects(interactorStoreObjectTypeName)
            assert(interactorStoreObjects.count == 0, "InteractorStoreObject wasn't fully migrated and there are still objects left inside.")
        }
    }
}
