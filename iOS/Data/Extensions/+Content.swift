//
//  +Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension StoredContent {
    func toHighlight() -> DaisukeEngine.Structs.Highlight {
        .init(id: contentId,
              cover: cover,
              title: title,
              additionalCovers: additionalCovers.toArray(),
              acquisitionLink: acquisitionLink,
              streamable: streamable)
    }

    func toDSKContent() throws -> DSKCommon.Content {
        let data = try DaisukeEngine.encode(value: self)
        return try DaisukeEngine.decode(data: data, to: DSKCommon.Content.self)
    }
}

extension DaisukeEngine.Structs.Content {
    func toStoredContent(with identifier: ContentIdentifier) throws -> StoredContent {
        let data = try DaisukeEngine.encode(value: self)
        let stored = try DaisukeEngine.decode(data: data, to: StoredContent.self)
        stored.sourceId = identifier.sourceId
        stored.contentId = identifier.contentId
        return stored
    }
}

enum LibraryFlag: Int, PersistableEnum, CaseIterable, Identifiable, Codable {
    case reading, planned, completed, dropped, reReading, paused, unknown

    var description: String {
        switch self {
        case .reading:
            return "Reading"
        case .planned:
            return "Planning to read"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        case .reReading:
            return "Re-reading"
        case .paused:
            return "Paused"
        case .unknown:
            return "No Flag"
        }
    }

    var id: Int {
        hashValue
    }
}

extension DSKCommon.Highlight {
    func toStored(sourceId: String) -> StoredContent {
        let stored = StoredContent()
        stored.title = title
        stored.contentId = id
        stored.sourceId = sourceId
        stored.cover = cover
        stored.acquisitionLink = acquisitionLink
        stored.streamable = canStream

        return stored
    }
}
