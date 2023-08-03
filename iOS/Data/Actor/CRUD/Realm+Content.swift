//
//  Realm+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift

extension RealmActor {
    func storeContent(_ content: StoredContent) async {
        do {
            try await realm.asyncWrite {
                realm.add(content, update: .modified)
            }
        } catch {
            Logger.shared.error(error, "RealmActor")
        }
    }

    func getStoredContent(_ sourceId: String, _ contentId: String) -> StoredContent? {
        realm
            .objects(StoredContent.self)
            .where { $0.contentId == contentId && $0.sourceId == sourceId }
            .first
    }

    func getStoredContent(_ id: String) -> StoredContent? {
        return realm
            .objects(StoredContent.self)
            .where { $0.id == id }
            .first
    }

    func getStoredContents(ids: [String]) -> Results<StoredContent> {
        return realm
            .objects(StoredContent.self)
            .filter("id IN %@", ids)
            .sorted(by: \.title, ascending: true)
    }

    func refreshStored(contentId: String, sourceId: String) async {
        guard let source = await DSK.shared.getSource(id: sourceId) else {
            return
        }

        let data = try? await source.getContent(id: contentId)
        guard let stored = try? data?.toStoredContent(withSource: sourceId) else {
            return
        }
        await storeContent(stored)
    }
    
    func updateStreamable(id: String, _ value: Bool) async {
        let target = realm
            .objects(StoredContent.self)
            .where { $0.id == id }
            .first
        guard let target else { return }
        try! await realm.asyncWrite {
            target.streamable = value
        }
    }
}
