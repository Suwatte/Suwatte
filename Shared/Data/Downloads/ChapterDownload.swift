//
//  ChapterDownload.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

enum DownloadStatus: Int, PersistableEnum {
    case idle, active, queued, failing, completed, paused, cancelled
}

enum PageDownloadStatus {
    case active, completed, failed
}

typealias ChapterIndentifier = (source: String, content: String, chapter: String)

final class ICDMDownloadObject: Object, ObjectKeyIdentifiable {
    // Identifiers
    @Persisted(primaryKey: true) var _id: String
    @Persisted var dateAdded: Date
    @Persisted var status: DownloadStatus
    @Persisted var textData: String?
    @Persisted var chapter: StoredChapter? {
        didSet {
            guard let chapter = chapter else {
                return
            }
            _id = chapter._id
        }
    }

    func getIdentifiers() -> ChapterIndentifier {
        let splitted = _id.components(separatedBy: "||")
        return (splitted[0], splitted[1], splitted[2])
    }
}

extension DataManager {
    func getDownloadedPages(for id: String) -> [URL]? {
        let path = ICDM.shared.directory.appendingPathComponent(id)

        if !path.exists {
            return nil
        }
        let urls = try? FileManager.default.contentsOfDirectory(atPath: path.relativePath)
        guard let urls = urls else {
            return nil
        }

        return urls.map { URL(string: $0)! }
    }
}
