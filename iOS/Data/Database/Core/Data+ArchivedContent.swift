//
//  File.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//

import Foundation
import RealmSwift

extension DataManager {
    
    func saveArchivedFile(_ file: File) throws {
        let realm = try! Realm()
        
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
        
        let relativePath = file.url.path.replacingOccurrences(of: directory.path, with: "")

        let obj = ArchivedContent()
        obj.id = file.id
        obj.name = file.name
        obj.relativePath = relativePath
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }
    
    func getArchivedcontentInfo(_ id: String) -> ArchivedContent? {
        let realm = try! Realm()
        return realm
            .objects(ArchivedContent.self)
            .where({ $0.id == id && !$0.isDeleted })
            .first
    }
}
