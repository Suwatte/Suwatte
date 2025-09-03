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
    func getInteractorStoreDictionary() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: "InteractorStoreObjects") as? [String: String] ?? [:]
    }

    func setInteractorStoreDictionary(_ dict: [String: String]) {
        UserDefaults.standard.set(dict, forKey: "InteractorStoreObjects")
    }

    func setStoreValue(for key: String, value: String) async {
        var dict = getInteractorStoreDictionary()
        dict.updateValue(value, forKey: key)
        setInteractorStoreDictionary(dict)
    }

    func getStoreValue(for key: String) -> String? {
        var dict = getInteractorStoreDictionary()
        return dict[key]
    }

    func removeStoreValue(for key: String) async {
        var dict = getInteractorStoreDictionary()
        dict.removeValue(forKey: key)
        setInteractorStoreDictionary(dict)
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
