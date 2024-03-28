//
//  CDKVPair.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-19.
//

import Foundation
import CoreData
import KeychainSwift

extension CDKVPair {
    
}


extension CDKVPair {
    static func getPair(runner: String, key: String, context: NSManagedObjectContext = CDManager.shared.context) -> CDKVPair? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "(runner_ == %@) AND (key_ == %@)", runner, key)
        
        let result = try? context.fetch(request)
        
        return result?.first
    }
    
    static func getValue(runner: String, key: String, context: NSManagedObjectContext = CDManager.shared.context) -> String? {
        return getPair(runner: runner, key: key, context: context)?.value_
    }
    
    
    static func setPair(runner: String, key: String, value: String, context: NSManagedObjectContext = CDManager.shared.context) {
        
        let record = CDKVPair(context: context)
        
        record.runner_ = runner
        record.key_ = key
        record.value_ = value
        
        
        context.safeSave()
    }
    
    static func removePair(runner: String, key: String, context: NSManagedObjectContext = CDManager.shared.context) {
        
        let pair = getPair(runner: runner, key: key, context: context)
        
        guard let pair else { return }
        
        context.delete(pair)
    }
}


extension CDKVPair {
    static func getKeychainValue(for id: String, key: String) -> String? {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        return keychain.get("\(id)_\(key)")
    }

    static func setKeychainValue(for id: String, key: String, value: String) {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.set(value, forKey: "\(id)_\(key)")
    }

    static func deleteKeyChainValue(for id: String, key: String) {
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        keychain.delete("\(id)_\(key)")
    }
}
