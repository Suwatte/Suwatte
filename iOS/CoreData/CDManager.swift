//
//  CDManager.swift
//  Suwatte
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData
import SwiftUI

class CDManager: ObservableObject {
    
    static let shared = CDManager()
    
    let container = NSPersistentContainer(name: "Model")
    
    
    init() {
        container.loadPersistentStores { description, error in
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            if let error {
                Logger.shared.error(error)
                return
            }
            
            Logger.shared.debug("[CDManager] Store Loaded.")
        }
    }
    
    var context: NSManagedObjectContext {
        container.viewContext
    }
}
