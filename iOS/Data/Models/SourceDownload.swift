//
//  SourceDownload.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift

final class SourceDownload: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var dateAdded: Date
    @Persisted(indexed: true) var status: DownloadStatus

    @Persisted var chapter: StoredChapter?
    @Persisted var content: StoredContent?

    @Persisted var text: String?
    @Persisted var archive: String?
}

final class SourceDownloadIndex: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var dateFirstAdded: Date = .now
    @Persisted var dateLastAdded: Date = .now
    @Persisted var content: StoredContent?
    @Persisted var count: Int = 0
}
