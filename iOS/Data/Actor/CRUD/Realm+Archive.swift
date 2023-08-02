//
//  Realm+Archive.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    
    func saveArchivedFile(_ file: File) async {

        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)

        let relativePath = file.url.path.replacingOccurrences(of: directory.path, with: "")

        let obj = ArchivedContent()
        obj.id = file.id
        obj.name = file.metaData?.title ?? file.name
        obj.relativePath = relativePath
        try! await realm.asyncWrite {
            realm.add(obj, update: .modified)
        }
    }

    func getArchivedcontentInfo(_ id: String) -> ArchivedContent? {
        return realm
            .objects(ArchivedContent.self)
            .where { $0.id == id && !$0.isDeleted }
            .first
    }

    func getArchiveDateRead(_ id: String) -> Date {
        return realm.objects(ProgressMarker.self)
            .where { $0.currentChapter.archive.id == id && !$0.isDeleted }
            .first?
            .dateRead ?? .distantPast
    }
}
