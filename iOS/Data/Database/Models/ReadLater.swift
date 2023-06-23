//
//  ReadLater.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class ReadLater: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted var dateAdded = Date()
    @Persisted var content: StoredContent? {
        didSet {
            if let id = content?.id {
                self.id = id
            }
        }
    }

    @Persisted(primaryKey: true) var id: String
    @Persisted var isDeleted: Bool = false
}
