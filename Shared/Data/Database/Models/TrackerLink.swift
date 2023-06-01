//
//  TrackerLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream

final class TrackerLink: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var trackerInfo: StoredTrackerInfo?
    @Persisted var isDeleted: Bool = false
}
