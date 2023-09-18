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
        let identifier = ContentIdentifier(contentId: contentId, sourceId: sourceId).id
        return getObject(of: StoredContent.self, with: identifier)
    }

    func getStoredContent(_ id: String) -> StoredContent? {
        getObject(of: StoredContent.self, with: id)
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
        guard let stored = try? data?.toStoredContent(with: .init(contentId: contentId, sourceId: sourceId)) else {
            return
        }
        await storeContent(stored)
    }

    func updateStreamable(id: String, _ value: Bool) async {
        let target = getStoredContent(id)
        guard let target else { return }
        await operation {
            target.streamable = value
        }
    }
}
