//
//  +CDBackup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2024-03-28.
//

import Foundation

extension CDManager {
    func createBackup() throws -> Backup {
        var backup = Backup()
        backup.lists = try CDRunnerList.fetch().execute()
        return backup
    }
}



extension CDManager {
    func restore(backup: Backup) throws {
        try reset() // Reset DB
        
        
        
    }
}


extension CDManager {
    func reset() throws {
        
    }
}
