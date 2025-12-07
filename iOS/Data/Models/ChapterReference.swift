//
//  ChapterReference.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

protocol STTChapter {
    var number: Double { get set }
    var volume: Double? { get set }
}

extension STTChapter {
    var displayName: String {
        var str = ""
        if let volume = volume, volume != 0 {
            str += "Volume \(volume.clean)"
        }
        str += " Chapter \(number.clean)"
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var chapterName: String {
        "Chapter \(number.clean)"
    }

    var chapterOrderKey: Double {
        ThreadSafeChapter.orderKey(volume: volume, number: number)
    }
}

final class ChapterReference: Object, CKRecordConvertible, CKRecordRecoverable, STTChapter {
    @Persisted(primaryKey: true) var id: String
    @Persisted var chapterId: String
    @Persisted var number: Double
    @Persisted var volume: Double?
    @Persisted var contentId: String?
    @Persisted var content: StoredContent? {
        didSet {
            if let content = content {
                contentId = content.id
            }
        }
    }

    @Persisted var opds: StreamableOPDSContent? {
        didSet {
            if let opds = opds {
                contentId = opds.id
            }
        }
    }

    @Persisted var archive: ArchivedContent? {
        didSet {
            if let archive = archive {
                contentId = archive.id
            }
        }
    }

    @Persisted var isDeleted: Bool = false

    var isValid: Bool {
        content != nil || opds != nil || archive != nil
    }
}
