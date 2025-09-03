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
    @Persisted var chapter: ChapterReference?
    @Persisted var dateRead: Date? = .now
    @Persisted var lastPageRead: Int?
    @Persisted var totalPageCount: Int?
    @Persisted var lastPageOffsetPCT: Double?

    @Persisted var readChapters: MutableSet<Double>

    @Persisted var isDeleted: Bool = false

    var isCompleted: Bool {
        guard chapter != nil else { return false }

        guard let lastPageRead, let totalPageCount, totalPageCount >= 1, lastPageRead >= 1 else {
            return false
        }

        return totalPageCount == lastPageRead && lastPageOffsetPCT == nil
    }

    func setCompleted(hideInHistory: Bool = false) {
        totalPageCount = 1
        lastPageRead = 1
        lastPageOffsetPCT = nil

        if hideInHistory {
            dateRead = nil
        }
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
}

extension ProgressMarker {
    func toThreadSafe() -> ThreadSafeProgressMarker {
        .init(id: id,
              dateRead: dateRead,
              lastPageRead: lastPageRead,
              totalPageCount: totalPageCount,
              lastPageOffsetPCT: lastPageOffsetPCT,
              chapterOrderKey: chapter?.chapterOrderKey)
    }
}

struct ThreadSafeProgressMarker: Hashable, Identifiable, Sendable, Encodable {
    let id: String
    let dateRead: Date?
    let lastPageRead: Int?
    let totalPageCount: Int?
    let lastPageOffsetPCT: Double?
    let chapterOrderKey: Double?

    var isCompleted: Bool {
        guard let lastPageRead, let totalPageCount, totalPageCount >= 1, lastPageRead >= 1 else {
            return false
        }

        return totalPageCount == lastPageRead && lastPageOffsetPCT == nil
    }
}

extension ThreadSafeProgressMarker {
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
}
