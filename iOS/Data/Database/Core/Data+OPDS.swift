//
//  Data+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import KeychainSwift
import R2Shared
import RealmSwift
extension DataManager {
    func savePublication(_ publication: Publication, _ clientID: String) throws {
        let realm = try! Realm()
        guard let id = publication.metadata.identifier, let streamLink = publication.streamLink, let thumbnailURL = publication.thumbnailURL else {
            throw DSK.Errors.NamedError(name: "DataManager", message: "Missing publication properties")
        }

        let count = (streamLink.properties["count"] as? String).flatMap(Int.init)
        let lastRead = (streamLink.properties["lastRead"] as? String).flatMap(Int.init)

        guard let count, let lastRead else {
            throw DSK.Errors.NamedError(name: "OPDS", message: "failed to parse page count & read marker")
        }

        let obj = StreamableOPDSContent()
        obj.id = "\(clientID)||\(id)"
        obj.contentTitle = publication.metadata.title
        obj.contentThumbnail = thumbnailURL
        obj.streamLink = streamLink.href
        obj.lastRead = lastRead
        obj.pageCount = count

        obj.client = realm.objects(StoredOPDSServer.self).where { $0.id == clientID && $0.isDeleted == false }.first

        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func getPublication(id: String) -> StreamableOPDSContent? {
        let realm = try! Realm()

        let target = realm
            .objects(StreamableOPDSContent.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        return target
    }

    func getPublicationPageCount(id: String) -> Int? {
        let realm = try! Realm()

        let target = realm
            .objects(StreamableOPDSContent.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        return target?.pageCount
    }
}

extension DataManager {
    func saveNewOPDSServer(entry: OPDSView.AddNewServerSheet.NewServer) {
        let obj = StoredOPDSServer()
        obj.alias = entry.alias
        obj.host = entry.host
        obj.userName = entry.userName
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.add(obj)
        }

        // Save PW to KC
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.set(entry.password, forKey: "OPDS_\(obj.id)")
    }

    func removeOPDServer(id: String) {
        let realm = try! Realm()

        guard let target = realm.objects(StoredOPDSServer.self).where({ $0.id == id && $0.isDeleted == false }).first else {
            return
        }
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.delete("OPDS_\(target.id)")

        try! realm.safeWrite {
            target.isDeleted = true
        }
    }
    
    func renameOPDSServer(id: String, name: String) {
        let realm = try! Realm()

        guard let target = realm.objects(StoredOPDSServer.self).where({ $0.id == id && $0.isDeleted == false }).first else {
            return
        }
        
        try! realm.safeWrite {
            target.alias = name
        }
    }
}
