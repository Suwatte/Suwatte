//
//  CDArchive.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData


extension CDArchive {
    
    var archiveID: String {
        id_ ?? ""
    }
    
    var name: String {
        name_ ?? ""
    }
    
    var relativePath: String {
        path_ ?? ""
    }
}

extension CDArchive {
    static func add(_ file: File, context: NSManagedObjectContext = CDManager.shared.context) {
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)

        let relativePath = file.url.path.replacingOccurrences(of: directory.path, with: "")
        
        
        let record = CDArchive(context: context)
        
        record.id_ = file.id
        record.name_ = file.metaData?.title ?? file.name
        record.path_ = relativePath
        
        context.safeSave()
    }
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) -> CDArchive? {
        let request = CDArchive.fetchRequest()
        request.predicate = NSPredicate(format: "id_ == %@", id)
        
        do {
            let result = try context.fetch(request)
            return result.first
        } catch {
            Logger.shared.error(error)
            return nil
        }
        
    }
}



extension CDArchive {
    func getURL() -> URL? {
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
        let target = directory
            .appendingPathComponent(relativePath)

        if target.exists {
            return target
        }

        guard CloudDataManager.shared.isCloudEnabled else { return nil }

        let resources = try? target.resourceValues(forKeys: [.isUbiquitousItemKey])
        if let resources, let isInCloud = resources.isUbiquitousItem, isInCloud {
            return target
        }

        return nil
    }
}
