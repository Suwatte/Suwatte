//
//  Bookmark.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class Bookmark: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted var page: Int
    @Persisted var verticalOffset: Double?
    @Persisted var chapter: ChapterReference?
    @Persisted var dateAdded: Date
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var isDeleted: Bool = false
}


final class UpdatedBookmark: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var chapter: ChapterReference?
    @Persisted var isDeleted: Bool = false
    @Persisted var page: Int
    @Persisted var verticalOffset: Double?
    @Persisted var dateAdded: Date
    @Persisted var asset: CreamAsset?
}
