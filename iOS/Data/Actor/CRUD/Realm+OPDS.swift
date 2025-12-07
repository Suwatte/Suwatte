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

        let obj = StreamableOPDSContent()
        obj.id = "\(clientID)||\(id)"
        obj.contentTitle = publication.metadata.title
        obj.contentThumbnail = thumbnailURL
        obj.streamLink = streamLink.href
        obj.lastRead = lastRead ?? 0
        obj.pageCount = count ?? 0

        obj.client = realm.objects(StoredOPDSServer.self).where { $0.id == clientID && $0.isDeleted == false }.first

        await operation {
            realm.add(obj, update: .modified)
        }
    }

    func getPublication(id: String, freezed: Bool = true) -> StreamableOPDSContent? {
        guard let content = getObject(of: StreamableOPDSContent.self, with: id), !content.isDeleted else {
            return nil
        }

        return freezed ? content.freeze() : content
    }

    func getPublicationPageCount(id: String) -> Int? {
        let target = getPublication(id: id)

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
            realm.add(obj, update: .modified)
        }

        // Save PW to KC
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.set(entry.password, forKey: "OPDS_\(obj.id)")
    }

    func removeOPDServer(id: String) async {
        guard let target = getObject(of: StoredOPDSServer.self, with: id) else {
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
        guard let target = getObject(of: StoredOPDSServer.self, with: id) else {
            return
        }

        await operation {
            target.alias = name
        }
    }
}
