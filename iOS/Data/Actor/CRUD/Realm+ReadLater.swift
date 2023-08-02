//
//  Realm+ReadLater.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func toggleReadLater(_ source: String, _ content: String) async {
        let id = ContentIdentifier(contentId: content, sourceId: source).id
        if let obj = realm.objects(ReadLater.self).first(where: { $0.id == id && $0.isDeleted == false }) {
            try! await realm.asyncWrite {
                obj.isDeleted = true
            }
            return
        }

        await addToReadLater(source, content)
    }

    func removeFromReadLater(_ source: String, content: String) async {
        guard let obj = realm.objects(ReadLater.self).first(where: { $0.content?.contentId == content && $0.content?.sourceId == source && $0.isDeleted == false }) else {
            return
        }

        try! await realm.asyncWrite {
            obj.isDeleted = true
        }
    }

    func addToReadLater(_ sourceID: String, _ contentID: String) async {
        // Get Stored Content
        let obj = ReadLater()

        let storedContent = realm.objects(StoredContent.self).first(where: { $0.contentId == contentID && $0.sourceId == sourceID })

        if let storedContent = storedContent {
            obj.content = storedContent
            try! await realm.asyncWrite {
                realm.add(obj, update: .modified)
            }
            return
        }

        guard let source = DSK.shared.getSource(id: sourceID) else {
            ToastManager.shared.error("[ReadLater] Source not Found")
            return
        }

        Task {
            do {
                let content = try await source.getContent(id: contentID)
                let storedContent = try content.toStoredContent(withSource: sourceID)

                let realm = try Realm(queue: nil)
                try! await realm.asyncWrite {
                    realm.add(storedContent)
                    obj.content = storedContent
                    realm.add(obj, update: .all)
                }
            } catch {
                ToastManager.shared.error(error)
            }
        }
    }
}
