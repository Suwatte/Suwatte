//
//  Backup+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Seyden on 05.08.24.
//

import Foundation
import RealmSwift

struct CodableContentLink: Codable {
    var id: String
    var libraryEntryId: String
    var contentId: String

    static func from(contentLink: ContentLink) -> Self {
        .init(id: contentLink.id, libraryEntryId: contentLink.entry!.id, contentId: contentLink.content!.id)
    }

    func restore(storedContent: [String: [StoredContent]], library: [LibraryEntry]?) -> ContentLink? {
        if let library = library {
            let content = storedContent[contentId]?.first
            let entry = library.first { $0.id == libraryEntryId }

            guard let entry, let content else {
                return nil
            }

            let contentLink = ContentLink()
            contentLink.id = id
            contentLink.content = content
            contentLink.entry = entry

            return contentLink
        }

        return nil
    }
}
