//
//  ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift

class StoredChapterData: Object {
    @Persisted var chapter: StoredChapter? {
        didSet {
            guard let chapter = chapter else {
                return
            }
            _id = chapter.id
        }
    }

    @Persisted(primaryKey: true) var _id: String

    @Persisted var pages: List<StoredChapterPage>
    @Persisted var text: String?

    var imageURLs: [String] {
        pages.compactMap { $0.url }
    }

    var rawDatas: [String] {
        pages.compactMap { $0.raw?.toBase64() }
    }

    var urls: [URL] = []
    var archivePaths: [String] = []
    var archiveURL: URL?
    var opdsInfo: OPDSInfo?
}

class StoredChapterPage: EmbeddedObject, Parsable {
    @Persisted var url: String?
    @Persisted var raw: String?
}
