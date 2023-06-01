//
//  LibraryEntry.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream


final class LibraryEntry: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable{
    // Core
    @Persisted(primaryKey: true) var id: String
    @Persisted var content: StoredContent? {
        didSet {
            if let content = content {
                id = content.id
            }
        }
    }

    // Update information
    @Persisted var updateCount: Int
    @Persisted var lastUpdated: Date = .distantPast

    // Dates
    @Persisted var dateAdded: Date
    @Persisted var lastRead: Date = .distantPast
    @Persisted var lastOpened: Date = .distantPast

    // Collections
    @Persisted var collections = List<String>()
    @Persisted var flag = LibraryFlag.unknown
    @Persisted var linkedHasUpdates = false

    @Persisted var unreadCount: Int
    @Persisted var isDeleted = false
}

