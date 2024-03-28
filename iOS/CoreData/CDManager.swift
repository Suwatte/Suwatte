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

extension NSManagedObjectContext {
    func safeSave() {
        do {
            try save()
        } catch {
            Logger.shared.error(error)
        }
    }
}


@available(iOS 15.0.0, *)
extension NSManagedObjectContext {
    func get<E, R>(request: NSFetchRequest<E>) async throws -> [R] where E: NSManagedObject, E: ThreadSafeMappable, R == E.SafeType {
        try await self.perform { [weak self] in
            try self?.fetch(request).compactMap { try $0.mapToThreadSafe() } ?? []
        }
    }
}

enum SafeMapError: Error {
    case invalidMapping
}

protocol ThreadSafeMappable {
    associatedtype SafeType
    func mapToThreadSafe() throws -> SafeType
}
