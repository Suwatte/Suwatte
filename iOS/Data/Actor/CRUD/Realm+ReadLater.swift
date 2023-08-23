//
//  Realm+ReadLater.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func getReadLater(for id: String) -> ReadLater? {
        realm
            .objects(ReadLater.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .first
    }

    func isSavedForLater(_ id: String) -> Bool {
        return !realm
            .objects(ReadLater.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
            .isEmpty
    }

    func toggleReadLater(_ source: String, _ content: String) async {
        let id = ContentIdentifier(contentId: content, sourceId: source).id

        let isSaved = isSavedForLater(id)

        if isSaved {
            await removeFromReadLater(source, content: content)
            return
        }

        await addToReadLater(source, content)
    }

    func removeFromReadLater(_ source: String, content: String) async {
        let id = ContentIdentifier(contentId: content, sourceId: source).id

        guard let target = getReadLater(for: id) else { return }

        try! await realm.asyncWrite {
            target.isDeleted = true
        }
    }

    func addToReadLater(_ sourceID: String, _ contentID: String) async {
        // Get Stored Content

        let content = getStoredContent(sourceID, contentID)

        guard let content else {
            await queryAndSaveForLater(sourceID, contentID)
            return
        }
        let obj = ReadLater()
        obj.content = content

        try! await realm.asyncWrite {
            realm.add(obj, update: .modified)
        }
    }

    func queryAndSaveForLater(_ sourceId: String, _ contentId: String) async {
        guard let source = await DSK.shared.getSource(id: sourceId) else {
            Logger.shared.warn("Source not Found", "RealmActor")
            return
        }

        do {
            let content = try await source.getContent(id: contentId)
            let storedContent = try content.toStoredContent(withSource: sourceId)

            let obj = ReadLater()
            obj.content = storedContent
            try! await realm.asyncWrite {
                realm.add(storedContent, update: .modified)
                obj.content = storedContent
                realm.add(obj, update: .all)
            }
        } catch {
            ToastManager.shared.error(error)
        }
    }
}
