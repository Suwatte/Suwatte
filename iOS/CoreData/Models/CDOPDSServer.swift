//
//  CDOPDSServer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData


extension CDOServer {
    var serverID: String {
        id_ ?? ""
    }
    
    var alias : String {
        alias_ ?? ""
    }
    
    var host: String {
        host_ ?? ""
    }
    
    var username: String {
        username_ ?? ""
    }
    
    var password: String {
        password_ ?? ""
    }
    
    
}


extension CDOServer {
    static func add(info: OPDSView.AddNewServerSheet.NewServer, context: NSManagedObjectContext = CDManager.shared.context) {
        
        let record = CDOServer(context: context)
        
        record.id_ = UUID().uuidString
        record.alias_ = info.alias
        record.host_ = info.host
        record.username_ = info.userName
        record.password_ = info.password
        
        context.safeSave()
    }
    
    
    static func remove(_ server: CDOServer) {
        guard let context = server.managedObjectContext else { return }
        context.delete(server)
    }
    
    static func rename(_ server: CDOServer, name: String) {
        server.alias_ = name
        guard let context = server.managedObjectContext else { return }
        
        
        context.safeSave()
    }
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) -> CDOServer? {
        let request = CDOServer.fetchRequest()
        request.predicate = NSPredicate(format: "id_ == %@", id)
        
        let result = try? context.fetch(request)
        
        return result?.first
    }
}

extension CDOServer {
    static func orderedFetch() -> NSFetchRequest<CDOServer> {
        let request = CDOServer.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "alias_", ascending: false)]
        return request
    }
}

extension CDOServer {
    func toClient() -> OPDSClient {
        var auth: (String, String)?
        if !username.isEmpty && !password.isEmpty  {
            auth = (username, password)
        }

        return .init(id: serverID, base: host, auth: auth)
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
