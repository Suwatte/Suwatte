//
//  CDOPublication.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-12-18.
//

import Foundation
import CoreData
import R2Shared



extension CDOPublication {
    var contentID: String {
        id_ ?? ""
    }
    
    var streamLink: String {
        link_ ?? ""
    }
    
    var thumbnail: String {
        thumbnail_ ?? ""
    }
    
    var title: String {
        title_ ?? ""
    }
        
}


extension CDOPublication {
    func toReadableChapter() -> ThreadSafeChapter {
        return .init(id: contentID,
                     sourceId: STTHelpers.OPDS_CONTENT_ID,
                     chapterId: streamLink,
                     contentId: contentID.components(separatedBy: "||").last ?? contentID,
                     index: 0,
                     number: 0,
                     volume: nil,
                     title: title,
                     language: "unknown",
                     date: .now,
                     webUrl: streamLink,
                     thumbnail: nil)
    }

    func read(onDismiss: (() -> Void)? = nil) {
        let chapter = toReadableChapter()
        let state = ReaderState(title: title,
                                chapter: chapter,
                                chapters: [chapter],
                                requestedPage: nil,
                                requestedOffset: nil,
                                readingMode: nil,
                                dismissAction: onDismiss)
        Task { @MainActor in
            StateManager.shared.openReader(state: state)
        }
    }
}


extension CDOPublication {
    
    static func get(id: String, context: NSManagedObjectContext = CDManager.shared.context) -> CDOPublication? {
        do {
            let request = CDOPublication.fetchRequest()
            request.predicate = NSPredicate(format: "id_ == %@", id)
            
            let result = try context.fetch(request)
            return result.first
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }
    
    static func add(publication: Publication, client: String ,  context: NSManagedObjectContext = CDManager.shared.context) throws {
        guard let id = publication.metadata.identifier, let streamLink = publication.streamLink else {
            throw DSK.Errors.NamedError(name: "DataManager", message: "Missing publication properties")
        }

        let thumbnailURL = publication.thumbnailURL
        let count = (streamLink.properties["count"] as? String).flatMap(Int.init)
        let lastRead = (streamLink.properties["lastRead"] as? String).flatMap(Int.init)
        
        let record = CDOPublication(context: context)
        
        
        record.id_ = "\(client)||\(id)"
        record.title_ = publication.metadata.title
        record.thumbnail_ = thumbnailURL
        record.link_ = streamLink.href
        record.lastRead = Int32(lastRead ?? 0)
        record.pageCount = Int32(count ?? 0)
        
        record.server = CDOServer.get(id: client)
        
        context.safeSave()
        
    }
}
