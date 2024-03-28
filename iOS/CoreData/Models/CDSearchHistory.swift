//
//  +CDSearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-19.
//

import Foundation
import CoreData

extension CDSearchHistory {

    
    
    static func add(_ r : DSKCommon.DirectoryRequest, source: String?, label: String, context: NSManagedObjectContext = CDManager.shared.context) {
        let incognito = Preferences.standard.incognitoMode
        guard !incognito else { return }
        
        let req = try? JSONEncoder().encode(r)
        
        guard let req else { return }
        
        let record = CDSearchHistory(context: context)
        
        record.date = .now
        record.source_ = source
        record.display_ = label
        record.request = req
    }
    
    
    static func remove(_ r: CDSearchHistory) {
        guard let context = r.managedObjectContext else { return }
        
        context.delete(r)
    }
    
    
    static func removeAll(context: NSManagedObjectContext = CDManager.shared.context) {
        let request = fetchRequest()
        let result = try? context.fetch(request)
        guard let result else { return }
        
        for entry in result {
            context.delete(entry)
        }
        context.safeSave()
    }
    
}


extension CDSearchHistory {
    static func globalSearchRequest() -> NSFetchRequest<CDSearchHistory> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date_", ascending: false)]
        request.predicate = NSPredicate(format: "source_ == nil")
        return request
    }
    
    static func singleSourceRequest(id: String) -> NSFetchRequest<CDSearchHistory> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date_", ascending: false)]
        request.predicate = NSPredicate(format: "source_ == %@", id)
        return request
    }
}
