//
//  OPDSClient.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import Foundation
import IceCream
import KeychainSwift
import RealmSwift

final class StoredOPDSServer: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id = UUID().uuidString
    @Persisted var alias: String
    @Persisted(indexed: true) var host: String
    @Persisted var userName: String
    @Persisted var isDeleted: Bool = false

    func toClient() -> OPDSClient {
        var auth: (String, String)?
        if !userName.isEmpty {
            let kc = KeychainSwift()
            kc.synchronizable = true
            let pw = kc.get("OPDS_\(id)")
            if let pw = pw {
                auth = (userName, pw)
            }
        }

        return .init(id: id, base: host, auth: auth)
    }
}
