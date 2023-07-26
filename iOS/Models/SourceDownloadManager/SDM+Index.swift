//
//  SDM+Index.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift

extension SDM {
    
    func updateIndex(of content: StoredContent) {
        let realm = try! Realm()
        
        let collection = realm
            .objects(SourceDownload.self)
            .where { $0.content.id == content.id }
            .where { $0.status == .completed }
            .sorted(by: \.dateAdded, ascending: true) // First Points to earliest, last points to latest
        
        let count = collection.count
        
        var target = realm
            .objects(SourceDownloadIndex.self)
            .where { $0.id == content.id }
            .first
        
        // Target not found, new index, create
        if target == nil {
            let idx = SourceDownloadIndex()
            idx.id = content.id
            idx.content = content
            target = idx
        }
        
        guard let target else { return }
        

        
        try! realm.safeWrite {
            if let earliest = collection.first {
                target.dateFirstAdded = earliest.dateAdded
            }
            
            if let latest = collection.last {
                target.dateLastAdded = latest.dateAdded
            }
            
            target.count = count
            realm.add(target, update: .modified)
        }
    }
}
