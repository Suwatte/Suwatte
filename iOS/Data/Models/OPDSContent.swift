//
//  OPDSContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class StreamableOPDSContent: Object, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var contentTitle: String
    @Persisted var contentThumbnail: String
    @Persisted var streamLink: String
    @Persisted var pageCount: Int
    @Persisted var lastRead: Int
    @Persisted var client: StoredOPDSServer?
    @Persisted var isDeleted: Bool
}

extension StreamableOPDSContent {
    func toReadableChapter() -> ThreadSafeChapter {
        return .init(id: id,
                     sourceId: STTHelpers.OPDS_CONTENT_ID,
                     chapterId: streamLink,
                     contentId: id.components(separatedBy: "||").last ?? id,
                     index: 0,
                     number: 0,
                     volume: nil,
                     title: contentTitle,
                     language: "unknown",
                     date: .now,
                     webUrl: streamLink,
                     thumbnail: nil)
    }

    func read(onDismiss: (() -> Void)? = nil) {
        let chapter = toReadableChapter()
        let state = ReaderState(title: contentTitle,
                                chapter: chapter,
                                chapters: [chapter],
                                requestedPage: nil,
                                requestedOffset: nil,
                                readingMode: nil,
                                dismissAction: onDismiss)
        Task { @MainActor in
            StateManager.shared.openReader(state: state)
        }
    }
}
