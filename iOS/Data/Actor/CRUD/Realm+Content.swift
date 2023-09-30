//
//  Realm+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import RealmSwift

extension RealmActor {
    private func getStoredContent(_ sourceId: String, _ contentId: String) -> StoredContent? {
        let identifier = ContentIdentifier(contentId: contentId, sourceId: sourceId).id
        return getObject(of: StoredContent.self, with: identifier)
    }

    func getStoredContent(_ id: String) -> StoredContent? {
        getObject(of: StoredContent.self, with: id)
    }
}

extension RealmActor {
    func getDSKContent(_ id: String) -> DSKCommon.Content? {
        try? getObject(of: StoredContent.self, with: id)?
            .toDSKContent()
    }

    func getFrozenContent(_ id: String) -> StoredContent? {
        getStoredContent(id)?.freeze()
    }

    func isContentSaved(_ id: String) -> Bool {
        return getStoredContent(id) != nil
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

    func storeContent(_ content: StoredContent) async {
        do {
            try await realm.asyncWrite {
                realm.add(content, update: .modified)
            }
        } catch {
            Logger.shared.error(error, "RealmActor")
        }
    }
}
