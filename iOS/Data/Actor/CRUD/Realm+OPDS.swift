//
//  Realm+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import KeychainSwift
import R2Shared
import RealmSwift

extension RealmActor {
    func savePublication(_ publication: Publication, _ clientID: String) async throws {
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

        await operation {
            realm.add(obj, update: .modified)
        }
    }

    func getPublication(id: String) -> StreamableOPDSContent? {
        let target = realm
            .objects(StreamableOPDSContent.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        return target
    }

    func getPublicationPageCount(id: String) -> Int? {
        let target = realm
            .objects(StreamableOPDSContent.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        return target?.pageCount
    }
}

extension RealmActor {
    func saveNewOPDSServer(entry: OPDSView.AddNewServerSheet.NewServer) async {
        let obj = StoredOPDSServer()
        obj.alias = entry.alias
        obj.host = entry.host
        obj.userName = entry.userName

        await operation {
            realm.add(obj)
        }

        // Save PW to KC
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.set(entry.password, forKey: "OPDS_\(obj.id)")
    }

    func removeOPDServer(id: String) async {
        guard let target = realm.objects(StoredOPDSServer.self).where({ $0.id == id && $0.isDeleted == false }).first else {
            return
        }
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.delete("OPDS_\(target.id)")

        await operation {
            target.isDeleted = true
        }
    }

    func renameOPDSServer(id: String, name: String) async {
        guard let target = realm.objects(StoredOPDSServer.self).where({ $0.id == id && $0.isDeleted == false }).first else {
            return
        }

        await operation {
            target.alias = name
        }
    }
}
