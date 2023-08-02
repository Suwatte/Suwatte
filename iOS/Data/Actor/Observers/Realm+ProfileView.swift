//
//  Realm+ProfileView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import Foundation
import RealmSwift

extension RealmActor {
    typealias Callback<T> = (T) -> Void
    func observeLibraryState(for id: String, _ callback: @escaping Callback<Bool>) async -> NotificationToken {
        let collection = realm
            .objects(LibraryEntry.self)
            .where { $0.id == id && !$0.isDeleted }
        
        func didUpdate(_ results: Results<LibraryEntry>) {
            let inLibrary = !results.isEmpty
            Task { @MainActor in
                callback(inLibrary)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate)
    }
    
    func observeReadLaterState(for id: String, _ callback: @escaping Callback<Bool>)  async -> NotificationToken {
        let collection = realm
            .objects(ReadLater.self)
            .where { $0.id == id }
            .where { !$0.isDeleted }
        
        func didUpdate(_ results: Results<ReadLater>) {
            let savedForLater = !results.isEmpty
            Task { @MainActor in
                callback(savedForLater)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate)
    }
    
    func observeReadChapters(for id: String,  _ callback: @escaping Callback<Set<Double>>) async -> NotificationToken {
        let collection = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id && !$0.isDeleted }
        
        func didUpdate(_ results: Results<ProgressMarker>) {
            guard let target = results.first else {
                Task { @MainActor in
                    callback([])
                }
                return
            }
            
            let readChapters = Set(target.readChapters)
            Task { @MainActor in
                callback(readChapters)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate)
    }
    
    func observeDownloadStatus(for id: String, _ callback: @escaping Callback<Dictionary<String, DownloadStatus>>) async -> NotificationToken {
        
        let contents = getLinkedContent(for: id, false)
            .map(\.id)
        
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.content != nil }
            .where { $0.content.id.in(contents) }
        
        func didUpdate(_ results: Results<SourceDownload>) {
            let dictionary = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0.status) })
            Task { @MainActor in
                callback(dictionary)
            }
        }
        
        return await observeCollection(collection: collection, didUpdate)
    }
}