//
//  Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

extension ContentStatus: PersistableEnum, Codable {}
extension ReadingMode: PersistableEnum, Codable {}

final class StoredContent: Object, Identifiable, CKRecordConvertible, CKRecordRecoverable {
    // Identifiers
    @Persisted(primaryKey: true) var id: String
    @Persisted(indexed: true) var sourceId: String {
        didSet {
            updateId()
        }
    }

    @Persisted(indexed: true) var contentId: String {
        didSet {
            updateId()
        }
    }

    @Persisted(indexed: true) var title: String
    @Persisted var cover: String

    @Persisted var webUrl: String?
    @Persisted var summary: String?

    @Persisted var additionalTitles: List<String>
    @Persisted var additionalCovers: List<String>
    @Persisted var properties: List<StoredProperty>

    @Persisted var creators: List<String>
    @Persisted var status: ContentStatus = .UNKNOWN
    @Persisted var recommendedReadingMode: ReadingMode = .PAGED_MANGA
    @Persisted var contentType: ExternalContentType = .unknown
    @Persisted var trackerInfo: Map<String, String>

    @Persisted var acquisitionLink: String?
    @Persisted var streamable: Bool = false
    
    @Persisted var isNSFW = false
    @Persisted var isNovel = false

    var ContentIdentifier: ContentIdentifier {
        return .init(contentId: contentId, sourceId: sourceId)
    }

    @Persisted var isDeleted = false // Required For Sync

    fileprivate func updateId() {
        id = "\(sourceId)||\(contentId)"
    }
}

final class StoredProperty: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var ckId = UUID().uuidString
    @Persisted var id: String
    @Persisted var label: String
    @Persisted var tags: List<StoredTag>
    @Persisted var isDeleted = false
}

final class StoredTag: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var ckId = UUID().uuidString
    @Persisted var id: String
    @Persisted var label: String
    @Persisted var adultContent: Bool
    @Persisted var isDeleted = false
}

final class ChapterProvider: EmbeddedObject, Parsable, Identifiable {
    @Persisted var id: String
    @Persisted var name: String
    @Persisted var links: List<ChapterProviderLink>
}

extension DSKCommon.ChapterProviderType: PersistableEnum {}

final class ChapterProviderLink: EmbeddedObject, Parsable {
    @Persisted var url: String
    @Persisted var type: DSKCommon.ChapterProviderType
}
