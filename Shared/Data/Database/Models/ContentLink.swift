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
    @Persisted(primaryKey: true) var id = UUID().uuidString
    @Persisted var ids: MutableSet<String>
    @Persisted var isDeleted = false
}
