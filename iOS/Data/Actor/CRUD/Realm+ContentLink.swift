//
//  Realm+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift

extension RealmActor {
    func linkContent(_ parent: String, _ child: DSKCommon.Highlight, _ sourceId: String) async -> Bool {
        let id = ContentIdentifier(contentId: child.id, sourceId: sourceId).id
        await saveIfNeeded(child, sourceId)
        return await linkContent(parent, id)
    }

    func linkContent(_ one: String, _ two: String) async -> Bool {
        let matches = !realm
            .objects(ContentLink.self)
            .where { $0.entry.id == one && $0.content.id == two && $0.isDeleted == false }
            .isEmpty

        if matches {
            return false
        }

        let entry = realm.object(ofType: LibraryEntry.self, forPrimaryKey: one)
        guard let entry else {
            return false
        }

        let content = realm.object(ofType: StoredContent.self, forPrimaryKey: two)
        guard let content else {
            return false
        }

        let obj = ContentLink()
        obj.entry = entry
        obj.content = content

        await operation {
            realm.add(obj, update: .modified)
        }

        return true
    }

    func unlinkAll(for entry: String) async {
        let targets = realm
            .objects(ContentLink.self)
            .where { $0.entry.id == entry && !$0.isDeleted }

        guard !targets.isEmpty else {
            return
        }

        await operation {
            for target in targets {
                target.isDeleted = true
            }
        }
    }

    func unlinkContent(_ child: String, _ from: String) async {
        let target = realm
            .objects(ContentLink.self)
            .first { $0.entry?.id == from && $0.content?.id == child && !$0.isDeleted }

        guard let target else {
            return
        }
        await operation {
            target.isDeleted = true
        }
    }

    func getLinkedContent(for id: String) -> [StoredContent] {
        let contents = realm
            .objects(ContentLink.self)
            .where { $0.content != nil && $0.entry.id == id && !$0.isDeleted }
            .sorted(by: \.content!.title, ascending: true)
            .freeze()
            .toArray()
            .map { $0.content! }

        return contents
    }

    func getEntryContentForLinkedContent(for id: String) -> StoredContent? {
        let link = realm.objects(ContentLink.self)
            .first { $0.entry != nil && $0.content?.id == id && !$0.isDeleted }

        guard let link else {
            return nil
        }

        return link.freeze().entry!.content
    }

    func saveIfNeeded(_ h: DSKCommon.Highlight, _ sId: String) async {
        let result = realm
            .objects(StoredContent.self)
            .where { $0.sourceId == sId && $0.contentId == h.id }
        guard result.isEmpty else {
            return
        }

        let obj = h.toStored(sourceId: sId)
        await operation {
            realm.add(obj, update: .modified)
        }
    }
}
