//
//  CDRunnerList.swift
//  Suwatte
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData

// MARK: - Definition
@objc(CDRunnerList)
final class CDRunnerList : NSManagedObject  {}

// MARK: - Unwrapped Properties
extension CDRunnerList {
    var displayName: String {
        name_ ?? url_ ?? ""
    }
    
    var url : String {
        url_ ?? ""
    }
    
    var hasName: Bool {
        name_ != nil
    }
    
    convenience init(name: String?, url: URL, context: NSManagedObjectContext) {
        self.init(context: context)
        self.name_ = name
        self.url_ = url.absoluteString
    }
}


// MARK: - CRUD
extension CDRunnerList {
    
    /// Deletes a runner list from the DB
    static func delete(entry: CDRunnerList) {
        guard let context = entry.managedObjectContext else { return }
        context.delete(entry)
    }
    
    
    /// Adds a runner list to the DB
    static func add(entry: RunnerList, url: URL, context: NSManagedObjectContext = CDManager.shared.context) {
        let _ = CDRunnerList(name: entry.listName, url: url, context: context)
        do {
            try context.save()
        } catch {
            Logger.shared.error(error)
        }
    }
    
    /// Fetch All Runner Lists sorted by the name
    static func fetch() -> NSFetchRequest<CDRunnerList> {
        let request = CDRunnerList.fetchRequest()
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDRunnerList.name_, ascending: true)
        ]
        
        return request
    }
    
    /// Returns a boolean indicating whether any runner list has been installed
    static func noListInstalled(context: NSManagedObjectContext = CDManager.shared.context) -> Bool {
        let request = Self.fetchRequest()
        
        do {
            let result = try context.fetch(request)
            
            return result.isEmpty
        } catch {
            Logger.shared.error(error)
            return true
        }
        
    }
}

extension CDRunnerList: Codable {
    enum Keys: String, CodingKey {
        case listName, url
    }

    convenience init(from decoder: Decoder) throws {
        guard let context = decoder.userInfo[CodingUserInfoKey.managedObjectContext] as? NSManagedObjectContext else {
            throw DecoderConfigurationError.missingManagedObjectContext
          }

        self.init(context: context)
        let container = try decoder.container(keyedBy: Keys.self)
        
        name_ = try container.decodeIfPresent(String.self, forKey: .listName)
        url_ = try container.decode(String.self, forKey: .url)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(name_, forKey: .listName)
        try container.encode(url_, forKey: .url)
    }
    
}
