//
//  Comic.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import IceCream
import RealmSwift

extension StoredContent {
    func toHighlight() -> DaisukeEngine.Structs.Highlight {
        .init(contentId: contentId, cover: cover, title: title)
    }

    func convertProperties() -> [DSKCommon.Property] {
        properties.map { prop in
            let tags: [DSKCommon.Tag] = prop.tags.map { .init(id: $0.id, label: $0.label, nsfw: $0.adultContent) }

            return .init(id: UUID().uuidString, label: prop.label, tags: tags)
        }
    }

    func toDSKContent() throws -> DSKCommon.Content {
        let data = try DaisukeEngine.encode(value: self)
        return try DaisukeEngine.decode(data: data, to: DSKCommon.Content.self)
    }
}

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

        return realm
            .objects(StoredContent.self)
            .where { $0.contentId == contentId && $0.sourceId == sourceId }
            .first
    }

    func getStoredContent(_ id: String) -> StoredContent? {
        let realm = try! Realm()

        return realm
            .objects(StoredContent.self)
            .where { $0.id == id }
            .first
    }

    func getStoredContents(ids: [String]) -> Results<StoredContent> {
        let realm = try! Realm()

        return realm
            .objects(StoredContent.self)
            .filter("id IN %@", ids)
    }

    func refreshStored(contentId: String, sourceId: String) async {
        guard let source = DSK.shared.getSource(id: sourceId) else {
            return
        }

        let data = try? await source.getContent(id: contentId)
        guard let stored = try? data?.toStoredContent(withSource: sourceId) else {
            return
        }
        storeContent(stored)
    }
}
