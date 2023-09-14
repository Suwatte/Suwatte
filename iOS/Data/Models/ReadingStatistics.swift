//
//  ReadingStatistics.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-13.
//

import RealmSwift
import IceCream


final class UserReadingStatistic: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id = "default"
    @Persisted var isDeleted: Bool
    
    @Persisted var pagesRead: Int
    @Persisted var pixelsScrolled: Double
}
