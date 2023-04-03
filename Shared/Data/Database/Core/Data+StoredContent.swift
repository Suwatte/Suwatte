//
//  Comic.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import RealmSwift

final class StoredContent: Object, ObjectKeyIdentifiable {
    // Identifiers
    @Persisted(primaryKey: true) var _id: String
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
    @Persisted var adultContent: Bool = false
    @Persisted var recommendedReadingMode: ReadingMode = .PAGED_MANGA
    @Persisted var contentType: ExternalContentType = .unknown
    @Persisted var trackerInfo: Map<String, String>
    var SourceName: String {
        SourceManager.shared.getSource(id: sourceId)?.name ?? "Unrecognized : \(sourceId)"
    }

    var ContentIdentifier: ContentIdentifier {
        return .init(contentId: contentId, sourceId: sourceId)
    }
}

extension StoredContent {
    func updateId() {
        _id = "\(sourceId)||\(contentId)"
    }

    func toHighlight() -> DaisukeEngine.Structs.Highlight {
        .init(contentId: contentId, cover: cover, title: title)
    }

    func convertProperties() -> [DSKCommon.Property] {
        properties.map { prop in
            let tags: [DSKCommon.Tag] = prop.tags.map { .init(id: $0.id, label: $0.label, adultContent: $0.adultContent) }

            return .init(id: UUID().uuidString, label: prop.label, tags: tags)
        }
    }

    func toDSKContent() throws -> DSKCommon.Content {
        let data = try DaisukeEngine.encode(value: self)
        return try DaisukeEngine.decode(data: data, to: DSKCommon.Content.self)
    }
}

extension ContentStatus: PersistableEnum, Codable {}
extension ReadingMode: PersistableEnum, Codable {}

extension DaisukeEngine.Structs.Content {
    func toStoredContent(withSource source: String) throws -> StoredContent {
        let data = try DaisukeEngine.encode(value: self)
        let stored = try DaisukeEngine.decode(data: data, to: StoredContent.self)
        stored.sourceId = source
        return stored
    }
}

extension DataManager {
    func storeContent(_ content: StoredContent) {
        let realm = try! Realm()

        try! realm.safeWrite {
            realm.add(content, update: .modified)
        }
    }

    func getStoredContent(_ sourceId: String, _ contentId: String) -> StoredContent? {
        let realm = try! Realm()

        return realm.objects(StoredContent.self).first(where: { $0.contentId == contentId && $0.sourceId == sourceId })
    }

    func getLastRead(for content: StoredContent) -> ChapterMarker? {
        let realm = try! Realm()

        return realm.objects(ChapterMarker.self).first(where: { $0.chapter?.sourceId == content.sourceId && $0.chapter?.contentId == content.contentId })
    }

    func getStoredContents(ids: [String]) -> Results<StoredContent> {
        let realm = try! Realm()

        return realm
            .objects(StoredContent.self)
            .filter("_id IN %@", ids)
    }

    func refreshStored(contentId: String, sourceId: String) async {
        guard let source = SourceManager.shared.getSource(id: sourceId) else {
            return
        }

        let data = try? await source.getContent(id: contentId)
        guard let stored = try? data?.toStoredContent(withSource: sourceId) else {
            return
        }
        storeContent(stored)
    }
}
