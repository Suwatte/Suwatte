//
//  Realm+ValueStore.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import KeychainSwift
import RealmSwift

extension RealmActor {
    func setStoreValue(for id: String, key: String, value: String) async {
        let obj = InteractorStoreObject()
        obj.interactorId = id
        obj.key = key
        obj.value = value
        obj.prepareID()
        try! await realm.asyncWrite {
            realm.add(obj, update: .modified)
        }
    }

    func getStoreValue(for id: String, key: String) -> String? {
        return realm
            .objects(InteractorStoreObject.self)
            .where { $0.isDeleted == false }
            .where { $0.id == "\(id)|\(key)" }
            .first?
            .value
    }

    func removeStoreValue(for id: String, key: String) async {
        let target = realm
            .objects(InteractorStoreObject.self)
            .where { $0.key == key }
            .where { $0.interactorId == id }
            .first
        if let target {
            try! await realm.asyncWrite {
                target.isDeleted = true
            }
        }
    }
}

extension RealmActor {
    func getKeychainValue(for id: String, key: String) -> String? {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        return keychain.get("\(id)_\(key)")
    }

    func setKeychainValue(for id: String, key: String, value: String) {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.set(value, forKey: "\(id)_\(key)")
    }

    func deleteKeyChainValue(for id: String, key: String) {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.delete("\(id)_\(key)")
    }
}
