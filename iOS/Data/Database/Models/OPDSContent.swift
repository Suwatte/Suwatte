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
    func toStoredChapter() -> StoredChapter {
        let chapter = StoredChapter()
        chapter.sourceId = STTHelpers.OPDS_CONTENT_ID
        chapter.contentId = id.components(separatedBy: "||").last ?? id
        chapter.chapterId = streamLink
        chapter.id = id
        chapter.title = contentTitle
        chapter.thumbnail = contentThumbnail
        return chapter
    }

    func read(onDismiss: (() -> Void)? = nil) {
        let chapter = toStoredChapter()
        let state = ReaderState(title: contentTitle, chapter: chapter, chapters: [chapter], requestedPage: nil, readingMode: nil, dismissAction: onDismiss)
        StateManager.shared.openReader(state: state)
    }
}
