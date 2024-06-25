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
        
        let relativePath = file.url.path.components(separatedBy: directory.path).last
        
        guard let relativePath else {
            Logger.shared.error("unable to retrieve relative path of file")
            return
        }
        
        let obj = ArchivedContent()
        obj.id = file.id
        obj.name = file.metaData?.title ?? file.name
        obj.relativePath = relativePath
        await operation {
            realm.add(obj, update: .modified)
        }
    }
    
    func getArchivedContentInfo(_ id: String, freezed: Bool = true) -> ArchivedContent? {
        guard let content = getObject(of: ArchivedContent.self, with: id), !content.isDeleted else {
            return nil
        }
        
        return freezed ? content.freeze() : content
    }
}
