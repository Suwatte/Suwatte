//
//  CDCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData


extension CDCollection {
    var collectionID: String {
        id_ ?? ""
    }
    
    var name: String {
        name_ ?? ""
    }
    
    var order: Int {
        Int(order_)
    }
    
    
    var filter: ICollectionFilter? {
        guard let filter_ else { return nil }
        
        let val = try? JSONDecoder().decode(ICollectionFilter.self, from: filter_)
        if let val {
            return val
        }
        return nil
    }
}


extension CDCollection {
    
    static func add(name: String, context: NSManagedObjectContext = CDManager.shared.context) {
        let orderKey = getAll(context: context).count
        
        let record = CDCollection(context: context)
        record.id_ = UUID().uuidString
        record.name_ = name
        record.order_ = Int32(orderKey)
        
        context.safeSave()
    }
    
    static func rename(_ c: CDCollection, name: String) {
        guard let context = c.managedObjectContext else {
            return
        }
        c.name_ = name
        context.safeSave()
    }
    
    static func rename(_ id: String, name: String, context: NSManagedObjectContext = CDManager.shared.context) {
        
        
        guard let record = get(id: id, context: context) else {
            return
        }
        
        
        record.name_ = name
        context.safeSave()
    }
    
    static func remove(_ c: CDCollection) {
        guard let context = c.managedObjectContext else {
            return
        }
        
        context.delete(c)
    }
    
    static func remove(_ id: String, context: NSManagedObjectContext = CDManager.shared.context) {
        guard let record = get(id: id, context: context) else {
            return
        }
        
        
        context.delete(record)
    }
    
    static func getAll(context: NSManagedObjectContext = CDManager.shared.context) -> [CDCollection] {
        do {
            let result = try context.fetch(CDCollection.fetchRequest())
            
            return result
            
        } catch {
            Logger.shared.error(error)
            return []
        }
    }
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) -> CDCollection? {
        let request = CDCollection.fetchRequest()
        
        request.predicate = NSPredicate(format: "id_ == %@", id)
        
        do {
            let result = try context.fetch(request).first
            return result

        } catch {
            Logger.shared.error(error)
            return nil
        }
        
    }
    
    static func reorder(_ updated: [String], context: NSManagedObjectContext = CDManager.shared.context) {
        for (idx, id) in updated.enumerated() {
            guard let record = get(id: id, context: context) else { continue }
            record.order_ = Int32(idx)
        }
        
        context.safeSave()
    }
    
    static func addFilter(_ c: CDCollection, filter: ICollectionFilter) {
        guard let context = c.managedObjectContext else {
            return
        }
        
        c.filter_ = try? JSONEncoder().encode(filter)
        
        context.safeSave()
    }
    
    static func removeFilter(_ c: CDCollection) {
        guard let context = c.managedObjectContext else {
            return
        }
        
        c.filter_ = nil
        context.safeSave()
    }
}




extension CDCollection {
    static func fetchAll() -> NSFetchRequest<CDCollection> {
        let request = CDCollection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order_", ascending: true)]
        return request
    }
}
