//
//  LibraryCollectionFilter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream

final class LibraryCollectionFilter: Object, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var adultContent: ContentSelectionType = .both
    @Persisted var readingFlags: List<LibraryFlag>
    @Persisted var textContains: List<String>
    @Persisted var statuses: List<ContentStatus>
    @Persisted var sources: List<String>
    @Persisted var tagContains: List<String>
    @Persisted var contentType: List<ExternalContentType>
    @Persisted var isDeleted: Bool
}

