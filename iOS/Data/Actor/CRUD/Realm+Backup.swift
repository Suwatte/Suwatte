//
//  Realm+Backup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func createBackup() -> Backup {
        let libraryEntries = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }
            .freeze()

        let collections = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .freeze()

        let readLater = realm
            .objects(ReadLater.self)
            .where { $0.content != nil && !$0.isDeleted }
            .freeze()

        let progressMarkers = realm
            .objects(ProgressMarker.self)
            .where { $0.currentChapter != nil && $0.currentChapter.content != nil && !$0.isDeleted }
            .freeze()

        let lists = realm
            .objects(StoredRunnerList.self)
            .where { !$0.isDeleted }
            .freeze()

        let runners = realm
            .objects(StoredRunnerObject.self)
            .where { !$0.isDeleted }
            .freeze()

        var backup = Backup()
        
        backup.readLater = readLater.toArray()
        backup.progressMarkers = progressMarkers.toArray()
        backup.library = libraryEntries.toArray()
        backup.collections = collections.toArray()
        backup.runnerLists = lists.toArray()
        backup.runners = runners.toArray()

        return backup
    }
}
