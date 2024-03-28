//
//  CDKVPair.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-19.
//

import Foundation
import CoreData


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
