//
//  SDM+Database.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift

// MARK: Queue Helpers
extension SDM {
    
    internal func fetchQueue() {
        let realm = try! Realm()
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.status == .queued }
            .freeze()
            .toArray()
        
        setQueue(collection)
        
        let delete = realm.objects(SourceDownload.self)
    }
    /// in the case where the app is closed while a download is active, restart.
    private func restart() {
        let realm = try! Realm()
        
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.status == .active }
        
        try! realm.safeWrite {
            collection.forEach { object in
                object.dateAdded = .now
                object.status = .queued
            }
        }
    }
    
    internal func update(ids: [String], status: DownloadStatus) {
        let realm = try! Realm()
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(ids) }

        try! realm.safeWrite {
            for download in collection {
                download.status = status
                download.dateAdded = .now
            }
        }
    }
    
    func add(chapters: [String]) {
        let realm = try! Realm()

        // Get completed download ids
        let completed = realm
            .objects(SourceDownload.self)
            .where { $0.id.in(chapters) && $0.status == .completed }
            .map(\.id) as [String]
            

        // Get Stored Chapters
        let chapters = realm
            .objects(StoredChapter.self)
            .where { !$0.id.in(completed) } // Filter out Completed Downloads
            .where { $0.id.in(chapters) }
            .sorted(by: \.index, ascending: true)
        
        // Get the selected contents
        let contentIDs = Set(chapters.map(\.contentIdentifier.id))
        
        let contents = realm
            .objects(StoredContent.self)
            .where { $0.id.in(contentIDs) }
            .toArray()
        
        // create dictionary of content in ID: OBJECT
        let contentMap = Dictionary(uniqueKeysWithValues: contents.map { ($0.id, $0) } )

        // Create download objects for chapters
        let downloads = chapters
            .map { chapter -> SourceDownload in
                let download = SourceDownload()
                download.id = chapter.id
                download.chapter = chapter
                download.content = contentMap[chapter.contentIdentifier.id]
                download.status = .queued
                
                return download
            }

        // Update in DB
        try! realm.safeWrite {
            realm.add(downloads, update: .modified)
        }
        
        if queue.isEmpty {
            fetchQueue()
        }
    }
    
    internal func get(_ id: String) -> SourceDownload? {
        let realm = try! Realm()
        
        let target = realm
            .objects(SourceDownload.self)
            .where { $0.id == id }
            .first
        
        return target?.freeze()
    }
    
    internal func finished(_ id: String, url: URL) {
        let realm = try! Realm()
        
        let target = realm
            .objects(SourceDownload.self)
            .where { $0.id == id }
            .first
        guard let target else {
            Logger.shared.warn("Trying to update a download that does not exist (\(id))", CONTEXT)
            return
        }
        try! realm.safeWrite {
            target.path = url.absoluteString
        }
        
        Logger.shared.log("Operation Complete (\(id))")
    }
}

//
extension SDM {
    func resume(ids: [String]) {
        update(ids: ids, status: .queued)
        pausedTasks = pausedTasks.subtracting(ids)
    }
    
    func pause(ids: [String]) {
        update(ids: ids, status: .paused)
        pausedTasks = pausedTasks.union(ids)

    }

    func cancel(ids: [String]) {
        update(ids: ids, status: .cancelled)
        cancelledTasks = cancelledTasks.union(ids)
    }
}

extension SDM {
    internal func setText(_ id: String, _ text: String) {
        let realm = try! Realm()
        let download = realm
            .objects(SourceDownload.self)
            .where { $0.id == id  }
            .first
        
        guard let download else {
            Logger.shared.warn("Trying to update a download that does not exist (\(id))", CONTEXT)
            return
        }
        
        try! realm.safeWrite {
            download.text = text
        }
    }
}
