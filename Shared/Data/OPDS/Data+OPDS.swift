//
//  Data+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import Foundation
import KeychainSwift
import RealmSwift

final class StoredOPDSServer: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id = UUID().uuidString
    @Persisted var alias: String
    @Persisted(indexed: true) var host: String
    @Persisted var userName: String

    func toClient() -> OPDSClient {
        var auth: (String, String)?
        if !userName.isEmpty {
            let kc = KeychainSwift()
            kc.synchronizable = true
            let pw = kc.get("OPDS_\(_id)")
            if let pw = pw {
                auth = (userName, pw)
            }
        }

        return .init(base: host, auth: auth)
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
        keychain.set(entry.password, forKey: "OPDS_\(obj._id)")
    }
}
