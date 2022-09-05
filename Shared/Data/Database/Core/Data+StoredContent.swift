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
    @Persisted(indexed: true) var sourceId: String
    @Persisted(indexed: true) var contentId: String

    @Persisted var title: String
    @Persisted var additionalTitles: List<String>

    @Persisted var covers: List<String>
    @Persisted var creators: List<String>

    @Persisted var status: ContentStatus
    @Persisted var summary: String
    @Persisted var adultContent: Bool
    @Persisted var url: String

    @Persisted var properties: List<StoredProperty>

    var cover: String {
        covers.first ?? STTHost.coverNotFound.absoluteString
    }

    var SourceName: String {
        DaisukeEngine.shared.getSource(with: sourceId)?.name ?? "Unrecognized : \(sourceId)"
    }

    var ContentIdentifier: DaisukeEngine.Structs.SuwatteContentIdentifier {
        return .init(contentId: contentId, sourceId: sourceId)
    }

    var includedCollections: [DaisukeEngine.Structs.HighlightCollection]?
    @Persisted var trackerInfo: StoredTrackerInfo?
    @Persisted var recommendedReadingMode: ReadingMode = .PAGED_MANGA
    @Persisted var contentType: ExternalContentType = .unknown
}

extension StoredContent {
    func toHighlight() -> DaisukeEngine.Structs.Highlight {
        .init(id: contentId, covers: covers.toArray(), title: title, subtitle: nil, tags: nil, stats: nil, chapter: nil)
    }

    func convertProperties() -> [DSKCommon.Property] {
        properties.map { prop in
            let tags: [DSKCommon.Tag] = prop.tags.map { .init(id: $0.id, label: $0.label, adultContent: $0.adultContent) }

            return .init(id: UUID().uuidString, label: prop.label, tags: tags)
        }
    }
}

extension ContentStatus: PersistableEnum, Codable {}
extension ReadingMode: PersistableEnum, Codable {}

extension DaisukeEngine.Structs.Content {
    func toStoredContent(withSource source: DaisukeEngine.ContentSource) -> StoredContent {
        let content = StoredContent()

        content.sourceId = source.id
        content.contentId = id
        content.title = title
        content.additionalTitles.append(objectsIn: additionalTitles)
        content.covers.append(objectsIn: covers)
        content.status = status
        content.creators.append(objectsIn: creators)
        content.summary = summary
        content.adultContent = adultContent
        content.url = url
        content.properties.append(objectsIn: properties)
        content.includedCollections = includedCollections

        if let trackerInfo = trackerInfo {
            let info = StoredTrackerInfo()
            info.mal = trackerInfo.mal
            info.al = trackerInfo.al
            info.kt = trackerInfo.kt
            info.mu = trackerInfo.mu
            content.trackerInfo = info
        }
        content.recommendedReadingMode = recommendedReadingMode
        content.contentType = contentType
        content._id = "\(source.id)||\(id)"
        return content
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
}
