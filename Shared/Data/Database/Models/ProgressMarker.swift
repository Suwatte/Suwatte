//
//  ProgressMarker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class ProgressMarker: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var readChapters: MutableSet<Double>
    @Persisted var currentChapter: ChapterReference?
    @Persisted var dateRead: Date? = .now
    @Persisted var lastPageRead: Int?
    @Persisted var totalPageCount: Int?
    @Persisted var lastPageOffset: Double?

    @Persisted var isDeleted: Bool = false

    var isCompleted: Bool {
        guard let lastPageRead, let totalPageCount, totalPageCount >= 1, lastPageRead >= 1 else {
            return false
        }

        return totalPageCount == lastPageRead
    }
}

extension ProgressMarker {
    var progress: Double? {
        guard let lastPageRead, let totalPageCount else {
            return nil
        }
        return Double(lastPageRead) / Double(totalPageCount)
    }

    var pctProgress: Double? {
        if let progress {
            return progress * 100.0
        }
        return nil
    }

    var maxReadChapter: Double? {
        readChapters.max()
    }
}
