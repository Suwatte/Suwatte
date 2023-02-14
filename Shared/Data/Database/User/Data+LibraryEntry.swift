//
//  Data+LibraryEntry.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import Foundation
import RealmSwift

enum LibraryFlag: Int, PersistableEnum, CaseIterable, Identifiable, Codable {
    case reading, planned, completed, dropped, reReading, paused, unknown

    var description: String {
        switch self {
        case .reading:
            return "Reading"
        case .planned:
            return "Planning to read"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        case .reReading:
            return "Re-reading"
        case .paused:
            return "Paused"
        case .unknown:
            return "No Flag"
        }
    }

    var id: Int {
        hashValue
    }
}

final class LibraryEntry: Object, ObjectKeyIdentifiable {
    // Core
    @Persisted(primaryKey: true) var _id: String
    @Persisted var content: StoredContent? {
        didSet {
            if let content = content {
                _id = content._id
            }
        }
    }

    // Update information
    @Persisted var updateCount: Int
    @Persisted var lastUpdated: Date = .distantPast

    // Dates
    @Persisted var dateAdded: Date
    @Persisted var lastRead: Date = .distantPast
    @Persisted var lastOpened: Date = .distantPast

    // Collections
    @Persisted var collections = List<String>()
    @Persisted var flag = LibraryFlag.unknown
    @Persisted var linkedHasUpdates = false

    @Persisted var unreadCount: Int
}

extension DataManager {
    func setReadingFlag(for object: LibraryEntry, to flag: LibraryFlag) {
        guard let object = object.thaw() else {
            return
        }

        let realm = try! Realm()

        try! realm.safeWrite {
            object.flag = flag
        }

        guard let id = object.content?.contentId, let sourceId = object.content?.sourceId, let source = DaisukeEngine.shared.getJSSource(with: sourceId) else {
            return
        }
        Task {
            await source.onContentsReadingFlagChanged(contentIds: [id], flag: flag)
        }
    }

    func bulkSetReadingFlag(for ids: Set<String>, to flag: LibraryFlag) {
        let realm = try! Realm()

        let targets = realm
            .objects(LibraryEntry.self)
            .where { $0._id.in(ids) }

        try! realm.safeWrite {
            for target in targets {
                target.flag = flag
            }
        }

        let sourceIds = Set(targets.compactMap { $0.content?.sourceId })
        for id in sourceIds {
            guard let source = DaisukeEngine.shared.getJSSource(with: id) else {
                return
            }

            let contentIds = targets
                .where { $0.content.sourceId == id }
                .compactMap { $0.content?.contentId } as [String]

            Task {
                await source.onContentsReadingFlagChanged(contentIds: contentIds, flag: flag)
            }
        }
    }

    @discardableResult
    func toggleLibraryState(for content: StoredContent) -> Bool {
        let realm = try! Realm()

        let ids = content.ContentIdentifier
        let source = DaisukeEngine.shared.getJSSource(with: content.sourceId)
        if let target = realm.objects(LibraryEntry.self).first(where: { $0._id == content._id }) {
            // Run Removal Event
            Task {
                await source?.onContentsRemovedFromLibrary(ids: [ids.contentId])
            }
            // In Library, delete object
            try! realm.safeWrite {
                realm.delete(target)
            }
            return false
        }

        // Add To library
        let unread = getUnreadCount(for: .init(contentId: content.contentId, sourceId: content.sourceId), realm)
        try! realm.safeWrite {
            let obj = LibraryEntry()
            obj.content = content
            // Update Dates
            obj.lastRead = Date()
            obj.lastOpened = Date()
            obj.unreadCount = unread
            realm.add(obj, update: .modified)
        }

        // Get Ids
        let anilistId = content.trackerInfo["al"]

        // Run Addition Event
        Task {
            await source?.onContentsAddedToLibrary(ids: [ids.contentId])
        }

        Task {
            guard let indx = anilistId.map({ Int($0) }), let id = indx else {
                return
            }
            let _ = try? await Anilist.shared.beginTracking(id: id)
        }
        return true
    }

    func isInLibrary(content: StoredContent) -> Bool {
        let realm = try! Realm()

        return realm.objects(LibraryEntry.self).contains(where: { $0._id == content._id })
    }

    // MARK: Collections

    func clearCollections(for entry: LibraryEntry) {
        guard let entry = entry.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            entry.collections.removeAll()
        }
    }

    func toggleCollection(for entry: LibraryEntry, withId cid: String) {
        guard let entry = entry.thaw() else {
            return
        }
        let realm = try! Realm()

        try! realm.safeWrite {
            if entry.collections.contains(cid) {
                entry.collections.remove(at: entry.collections.firstIndex(of: cid)!)
            } else {
                entry.collections.append(cid)
            }
        }
    }

    func toggleCollection(for entry: String, withId cid: String) {
        let realm = try! Realm()

        guard let entry = realm.objects(LibraryEntry.self).where({ $0._id == entry }).first else { return }

        try! realm.safeWrite {
            if entry.collections.contains(cid) {
                entry.collections.remove(at: entry.collections.firstIndex(of: cid)!)
            } else {
                entry.collections.append(cid)
            }
        }
    }

    func batchRemoveFromLibrary(with ids: Set<String>) {
        let realm = try! Realm()

        let objects = realm.objects(LibraryEntry.self).filter { ids.contains($0._id) }

        let ids = objects.compactMap { $0.content?.ContentIdentifier }
        let grouped = Dictionary(grouping: ids, by: { $0.sourceId })

        for (key, value) in grouped {
            let source = DaisukeEngine.shared.getJSSource(with: key)
            Task {
                await source?.onContentsRemovedFromLibrary(ids: value.map { $0.contentId })
            }
        }

        try! realm.safeWrite {
            realm.delete(objects)
        }
    }

    func moveToCollections(entries: Set<String>, cids: [String]) {
        let realm = try! Realm()

        let objects = realm.objects(LibraryEntry.self).filter { entries.contains($0._id) }
        try! realm.safeWrite {
            objects.forEach {
                $0.collections.removeAll()
                $0.collections.append(objectsIn: cids)
            }
        }
    }

    func clearUpdates(id: String) {
        let realm = try! Realm()

        guard let entry = realm.objects(LibraryEntry.self).first(where: { $0._id == id }) else {
            return
        }

        try! realm.safeWrite {
            entry.updateCount = 0
            entry.lastOpened = Date()
        }
    }

    func updateLastRead(forId id: String) {
        let realm = try! Realm()

        guard let entry = realm.objects(LibraryEntry.self).first(where: { $0._id == id }) else {
            return
        }

        try! realm.safeWrite {
            entry.lastRead = Date()
        }
    }

    func getEntriesToBeUpdated(sourceId: String) -> [LibraryEntry] {
        let realm = try! Realm()

        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        // Filter out titles that may have been recently added
        return realm.objects(LibraryEntry.self)
            .filter { $0.dateAdded < date && $0.content?.sourceId == sourceId && $0.content?.status == .ONGOING }
    }

    func getUnreadCount(for id: ContentIdentifier, _ realm: Realm? = nil) -> Int {
        let realm = try! realm ?? Realm()
        // Get Read Count
        let read = realm
            .objects(ChapterMarker.self)
            .where { $0.chapter.contentId == id.contentId }
            .where { $0.chapter.sourceId == id.sourceId }
            .where { $0.completed == true }
            .distinct(by: [\.chapter?.number])
            .count
        // Get Total Chapter Count
        let total = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == id.contentId }
            .where { $0.sourceId == id.sourceId }
            .distinct(by: [\.number])
            .count
        return total - read
    }

    func updateUnreadCount(for id: ContentIdentifier, _ realm: Realm? = nil) {
        let realm = try! realm ?? Realm()

        let target = realm
            .objects(LibraryEntry.self)
            .where { $0.content.contentId == id.contentId }
            .where { $0.content.sourceId == id.sourceId }
            .first

        guard let target else { return }

        let count = getUnreadCount(for: id, realm)
        try! realm.safeWrite {
            target.unreadCount = count
        }
    }
}

extension DataManager {
    func contentInLibrary(s: String, c: String, realm: Realm? = nil) -> Bool {
        let realm = try! realm ?? Realm()

        return !realm
            .objects(LibraryEntry.self)
            .where { $0.content.contentId == c && $0.content.sourceId == s }
            .isEmpty
    }

    func contentSavedForLater(s: String, c: String, realm: Realm? = nil) -> Bool {
        let realm = try! realm ?? Realm()

        return !realm
            .objects(ReadLater.self)
            .where { $0.content.contentId == c && $0.content.sourceId == s }
            .isEmpty
    }
}
