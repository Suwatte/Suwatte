//
//  CustomThumbnail.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream

final class CustomThumbnail: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var file: CreamAsset?
    @Persisted var isDeleted: Bool = false
    static let FILE_KEY = "custom_thumb"
}
