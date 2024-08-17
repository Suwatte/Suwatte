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
            migration.delete(newContentLinkObject!)
        }
    }
    
    static func migrateProgressMarker(realm: Realm) {
        let progressMarkers = realm.objects(ProgressMarker.self)
            .where { !$0.isDeleted && $0.readChapters.count > 0 }
            .freeze()

        for progressMarker in progressMarkers {
            let contentId = progressMarker.id

            let dateRead = progressMarker.dateRead

            var migrated = false

            let readChapters = progressMarker.readChapters
            readChapterLoop: for readChapter in readChapters {
                let storedChapters = realm.objects(StoredChapter.self)
                    .where { $0.id.starts(with: contentId) }
                    .freeze()

                storedChapterLoop: for storedChapter in storedChapters {
                    let chapterOrderKey = ThreadSafeChapter.orderKey(volume: readChapter < 10000 ? 0 : storedChapter.volume, number: storedChapter.number)

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
                    let thawnMarker = progressMarker.thaw()
                    if let thawnMarker {
                        do {
                            try realm.write {

                                thawnMarker.readChapters.removeAll()
                                thawnMarker.isDeleted = true
                            }
                        } catch {
                            Logger.shared.error(error, "RealmActor")
                        }
                    }
                }
            }
        }

        let oldMarkers = realm.objects(ProgressMarker.self)
            .where { $0.readChapters.count > 0 }
            .freeze()

        if oldMarkers.count == 0 {
            UserDefaults.standard.set(true, forKey: STTKeys.OldProgressMarkersMigrated)
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
}
