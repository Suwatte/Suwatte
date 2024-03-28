//
//  CDRunner.swift
//  Suwatte
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData

struct DBRunner: Identifiable, Hashable {
    let id: String
    let thumbnail: String
    let name: String
    let version: Double
    let intents: RunnerIntents
    let environment: RunnerEnvironment
    let listURL: String?
}


// MARK: - Definition
extension CDRunner {
    var name: String {
        name_ ?? ""
    }
    
    var runnerID: String {
        id_ ?? ""
    }
    
    var thumbnail: String {
        thumbnail_ ?? ""
    }
    
    var environment: RunnerEnvironment {
        .init(rawValue: environment_ ?? "") ?? .unknown
    }
    
    var intents: RunnerIntents {
        guard let intents_ else { return .placeholder }
        
        let val = try? JSONDecoder().decode(RunnerIntents.self, from: intents_)
        if let val {
            return val
        }
        return .placeholder
    }
}


// MARK: - CRUD
extension CDRunner {
    /// Adds/Updates a runner.
    static func add(data: RunnerInfo, environment: RunnerEnvironment , list: URL? = nil, file: Data , context: NSManagedObjectContext = CDManager.shared.context) {
        
        let record = CDRunner(context: context)
        
        record.id_ = data.id
        record.name_ = data.name
        record.version = data.version
        record.executable = file
        record.environment_ = environment.rawValue
        record.listURL = list?.absoluteString
        if let thumbnail = data.thumbnail {
            record.thumbnail_ = parseRunnerThumbnail(list: list, thumbnail: thumbnail)
        }
        
        do {
            try context.save()
        } catch {
            Logger.shared.error(error)
        }
    }
    
    
    static func get(for id : String, context: NSManagedObjectContext = CDManager.shared.context) throws -> CDRunner? {
        let request = fetchSingle(id: id)
        let result = try context.fetch(request)
        return result.first
    }
    
    static func getExecutable(for id: String, context: NSManagedObjectContext = CDManager.shared.context) throws -> Data? {
        
        // first try getting from runners
        let runner = try get(for: id, context: context)
        
        return runner?.executable
    }
    
    static func remove(id: String, context: NSManagedObjectContext = CDManager.shared.context) throws {
        let runner = try get(for: id)
        
        guard let runner else { return }
        context.delete(runner)
    }
    
    static func getAll(context: NSManagedObjectContext = CDManager.shared.context) -> [DBRunner] {
        do {
            let request = CDRunner.fetchRequest()
            
            let results = try context.fetch(request)
            
            let data = results.map( { $0.toDB() })
            return data
        } catch {
            Logger.shared.error(error)
            return []
        }
    }
    
    static func getSources(context: NSManagedObjectContext = CDManager.shared.context) -> [DBRunner] {
        return getAll(context: context).filter({ $0.environment == .source })
    }
}

// MARK: - Requests
extension CDRunner {
    static func fetchSingle(id: String) -> NSFetchRequest<CDRunner> {
        let request = CDRunner.fetchRequest()
        request.predicate = NSPredicate(format: "id_ == %@", id)
        return request
    }
    
    static func fetchAllRequest() -> NSFetchRequest<CDRunner> {
        let request = CDRunner.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDRunner.name_, ascending: true)]
        return request
    }
}

// MARK: - Helpers
func parseRunnerThumbnail(list: URL?, thumbnail: String) -> String? {
    if thumbnail.contains("http") && URL(string: thumbnail) != nil {
        return thumbnail
    } else if let list {
        let path = list.appendingPathComponent("assets").appendingPathComponent(thumbnail)
        return path.absoluteString
    }
    
    return nil
}


extension CDRunner {
    func toDB() -> DBRunner {
        .init(id: runnerID,
              thumbnail: thumbnail,
              name: name,
              version: version,
              intents: intents,
              environment: environment,
              listURL: listURL)
    }
}
