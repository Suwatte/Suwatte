//
//  CDThumbnail.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2024-03-28.
//

import CoreData
import UIKit


extension CDThumbnail {
    static func set(image: UIImage, id: String, context: NSManagedObjectContext = CDManager.shared.context) async {
        let data = image.pngData()
        guard let data else  {
            Logger.shared.error("Unable to load PNG Data of image")
            return
        }
        await context.perform {
            let record = CDThumbnail(context: context)
            record.id_ = id
            record.data_ = data
            context.safeSave()
        }
    }
    
    static func remove(id: String, context: NSManagedObjectContext = CDManager.shared.context) async {
        let target = await CDThumbnail.get(id: id, context: context)
        guard let target else {
            return
        }
        await context.perform {
            context.delete(target)
        }
    }
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) async -> CDThumbnail? {
        await context.perform {
            let request = CDThumbnail.fetchRequest()
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
    
    static func getData(id: String, context: NSManagedObjectContext = CDManager.shared.context) async -> Data? {
        await context.perform {
            let request = CDThumbnail.fetchRequest()
            request.predicate = NSPredicate(format: "id_ == %@", id)
            
            do {
                let result = try context.fetch(request)
                return result.first?.data_
            } catch {
                Logger.shared.error(error)
                return nil
            }
        }
    }
}
