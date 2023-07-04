//
//  DataManager+ValueStore.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-16.
//

import Foundation
import KeychainSwift
import RealmSwift

extension DataManager {
    func setStoreValue(for id: String, key: String, value: String) {
        let realm = try! Realm()
        let obj = InteractorStoreObject()
        obj.interactorId = id
        obj.key = key
        obj.value = value
        obj.prepareID()
        try! realm.safeWrite {
            realm.add(obj, update: .modified)
        }
    }

    func getStoreValue(for id: String, key: String) -> String? {
        let realm = try! Realm()

        guard let obj = realm.objects(InteractorStoreObject.self).first(where: { $0.id == "\(id)|\(key)" }) else {
            return nil
        }

        return obj.value
    }

    func removeStoreValue(for id: String, key: String) {
        let realm = try! Realm()

        let target = realm
            .objects(InteractorStoreObject.self)
            .where { $0.key == key }
            .where { $0.interactorId == id }
            .first
        if let target {
            try! realm.safeWrite {
                target.isDeleted = true
            }
        }
    }
}

extension DataManager {
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