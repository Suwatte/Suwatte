//
//  LibraryCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream

final class LibraryCollection: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String
    @Persisted var order: Int
    @Persisted var filter: LibraryCollectionFilter?
    @Persisted var isDeleted: Bool
}
