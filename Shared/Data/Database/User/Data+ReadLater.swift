//
//  ReadLater.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//

import AlertToast
import Foundation
import RealmSwift

final class ReadLater: Object, ObjectKeyIdentifiable {
    @Persisted var dateAdded = Date()
    @Persisted var content: StoredContent? {
        didSet {
            if let id = content?._id {
                _id = id
            }
        }
    }

    @Persisted(primaryKey: true) var _id: String
}

extension DataManager {
    func toggleReadLater(_ source: String, _ content: String) {
        let id = ContentIdentifier(contentId: content, sourceId: source).id
        let realm = try! Realm()
        if let obj = realm.objects(ReadLater.self).first(where: { $0._id == id }) {
            try! realm.safeWrite {
                realm.delete(obj)
            }
            return
        }

        addToReadLater(source, content)
    }

    func removeFromReadLater(_ source: String, content: String) {
        let realm = try! Realm()

        guard let obj = realm.objects(ReadLater.self).first(where: { $0.content?.contentId == content && $0.content?.sourceId == source }) else {
            return
        }

        try! realm.safeWrite {
            realm.delete(obj)
        }
    }

    func addToReadLater(_ sourceID: String, _ contentID: String) {
        let realm = try! Realm()
        // Get Stored Content
        let obj = ReadLater()

        let storedContent = realm.objects(StoredContent.self).first(where: { $0.contentId == contentID && $0.sourceId == sourceID })

        if let storedContent = storedContent {
            obj.content = storedContent
            try! realm.safeWrite {
                realm.add(obj, update: .modified)
            }
            return
        }

        guard let source = DaisukeEngine.shared.getSource(with: sourceID) else {
            ToastManager.shared.toast = AlertToast(type: .error(.red), title: "Source Not Found")
            return
        }

        Task {
            do {
                let content = try await source.getContent(id: contentID)
                let storedContent = try content.toStoredContent(withSource: source)

                let realm = try Realm(queue: nil)
                try! realm.safeWrite {
                    realm.add(storedContent)
                    obj.content = storedContent
                    realm.add(obj, update: .all)
                }
            } catch {
                await MainActor.run(body: {
                    ToastManager.shared.setError(error: error)
                })
            }
        }
    }
}
