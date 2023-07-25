//
//  SourceDownload.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift


final class SourceDownload : Object {
    @Persisted(primaryKey: true) var id : String
    @Persisted var dateAdded: Date
    @Persisted var status: DownloadStatus
    
    @Persisted var chapter: StoredChapter?
    @Persisted var content: StoredContent?

    @Persisted var text: String?
    @Persisted var path: String?
}
