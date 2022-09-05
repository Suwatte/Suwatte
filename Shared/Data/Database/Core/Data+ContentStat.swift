//
//  Data+ContentStat.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-13.
//

import Foundation
import RealmSwift

final class ContentStat: Object {
    @Persisted(primaryKey: true) var _id: String
    @Persisted var chapterCount: Int
    @Persisted var lastOpened: Date
    @Persisted var lastRead: Date
}
