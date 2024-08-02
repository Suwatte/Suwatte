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

            var ids = Set(oldContentLinkObject["ids"] as! RealmSwift.MutableSet<String>)

            migration.enumerateObjects(ofType: LibraryEntry.className()) { _, libraryEntryObject in
                if let libraryEntryId = libraryEntryObject!["id"] as? String {

                    if ids.remove(libraryEntryId) != nil {

                        ids.forEach { linkContentId in
                            let newLink = migration.create(ContentLink.className())
                            newLink["id"] = "\(libraryEntryId)||\(linkContentId)"
                            newLink["entry"] = libraryEntryObject

                            migration.enumerateObjects(ofType: StoredContent.className()) { _, contentObject in
                                if let contentId = contentObject!["id"] as? String {
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
}
