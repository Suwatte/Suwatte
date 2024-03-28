//
//  CDArchive.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData

// MARK: - Definition
@objc(CDArchive)
public final class CDArchive : NSManagedObject  {}


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
    static func add(_ file: File, context: NSManagedObjectContext = CDManager.shared.context) throws {
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
        
        let relativePath = file.url.path.replacingOccurrences(of: directory.path, with: "")
        let bookmark = try file.bookmark()
        
        
        let record = CDArchive(context: context)
        record.id_ = file.id
        record.name_ = file.metaData?.title ?? file.name
        record.path_ = relativePath
        record.bookmark_ = bookmark
        context.safeSave()
    }
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) async -> TSArchive? {
        let request = CDArchive.fetchRequest()
        request.predicate = NSPredicate(format: "id_ == %@", id)
        
        do {
            let result = try await context.get(request: request)
            return result.first
        } catch {
            Logger.shared.error(error)
            return nil
        }
        
    }
}

extension CDArchive: ThreadSafeMappable {
    func mapToThreadSafe() -> TSArchive {
        return .init(ID: self.archiveID,
                     name: self.name,
                     path: self.relativePath,
                     bookmark: self.bookmark_)
    }
}



struct TSArchive {
    let ID: String
    let name : String
    let path : String
    let bookmark: Data?
}

extension TSArchive {
    func getURL() -> URL? {
        
        if let bookmark {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmark,
                                  bookmarkDataIsStale: &isStale)
                
                if isStale {
                    // TODO: Update Bookmark Data
                    print("Stale Bookmark Update")
                }
                
                Logger.shared.debug("Using Bookmark for \(ID)")
                return url
            } catch {
                Logger.shared.error(error)
            }
        }
                
        
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
        let target = directory
            .appendingPathComponent(path)
        
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




