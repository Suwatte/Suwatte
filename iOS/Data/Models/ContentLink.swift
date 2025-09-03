//
//  ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class ContentLink: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String

    @Persisted var entry: LibraryEntry? {
        didSet {
            updateId()
        }
    }

    @Persisted var content: StoredContent? {
        didSet {
            updateId()
        }
    }

    @Persisted var isDeleted = false

    fileprivate func updateId() {
        id = "\(entry?.id ?? "")||\(content?.id ?? "")"
    }
}
