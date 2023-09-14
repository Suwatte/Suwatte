//
//  Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class UpdatedBookmark: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var chapter: ChapterReference?
    @Persisted var isDeleted: Bool = false
    @Persisted var page: Int
    @Persisted var pageOffsetPCT: Double?
    @Persisted var dateAdded: Date = .now
    @Persisted var asset: CreamAsset?
}

final class ChapterBookmark: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var chapter: ChapterReference?
    @Persisted var dateAdded: Date = .now
    @Persisted var isDeleted: Bool = false
}
