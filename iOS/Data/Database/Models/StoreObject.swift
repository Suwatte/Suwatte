//
//  StoreObject.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import KeychainSwift
import RealmSwift

final class InteractorStoreObject: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var interactorId: String
    @Persisted var key: String
    @Persisted var value: String
    @Persisted var isDeleted: Bool = false

    func prepareID() {
        id = "\(interactorId)|\(key)"
    }
}
