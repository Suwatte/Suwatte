//
//  SearchHistory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class UpdatedSearchHistory: Object, Identifiable, Codable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted var sourceId: String?
    @Persisted var data: String // JSON String of SearchRequest
    @Persisted var displayText: String
    @Persisted var date: Date = .now
    @Persisted(primaryKey: true) var id = UUID().uuidString
    @Persisted var isDeleted = false
}
