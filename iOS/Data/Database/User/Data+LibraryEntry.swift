//
//  Data+LibraryEntry.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import Foundation
import IceCream
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

extension DataManager {
    func setReadingFlag(for object: LibraryEntry, to flag: LibraryFlag) {
        guard let object = object.thaw() else {
            return
        }

        let realm = try! Realm()

        try! realm.safeWrite {
            object.flag = flag
        }

        guard let id = object.content?.contentId, let sourceId = object.content?.sourceId, let source = SourceManager.shared.getSource(id: sourceId), source.intents.contentEventHandler else {
            return
        }
        Task {
            do {
                try await source.onContentsReadingFlagChanged(ids: [id], flag: flag)
            } catch {
                ToastManager.shared.error(error)
                Logger.shared.error(error.localizedDescription)
            }
        }
    }

    func bulkSetReadingFlag(for ids: Set<String>, to flag: LibraryFlag) {
        let realm = try! Realm()

        let targets = realm
            .objects(LibraryEntry.self)
            .where { $0.id.in(ids) }

        try! realm.safeWrite {
            for target in targets {
                target.flag = flag
            }
        }
        

        let sourceIds = Set(targets.compactMap { $0.content?.sourceId })
        for id in sourceIds {
            let source = try? SourceManager.shared.getSource(id: id)

            guard let source, source.intents.contentEventHandler else {
                continue
            }

            let contentIds = targets
                .where { $0.content.sourceId == id }
                .compactMap { $0.content?.contentId } as [String]

            Task {
                do {
                    try await source.onContentsReadingFlagChanged(ids: contentIds, flag: flag)
                } catch {
                    ToastManager.shared.error(error)
                    Logger.shared.info(error.localizedDescription)
                }
            }
        }
    }

    @discardableResult
    func toggleLibraryState(for content: StoredContent) -> Bool {
        let realm = try! Realm()

        let ids = content.ContentIdentifier
        let source = SourceManager.shared.getSource(id: content.sourceId)
        if let target = realm.objects(LibraryEntry.self).first(where: { $0.id == content.id }) {
            // Run Removal Event
            Task {
                do {
                    try await source?.onContentsRemovedFromLibrary(ids: [ids.contentId])
                } catch {
                    ToastManager.shared.info("Failed to Sync With Content Source")
                    Logger.shared.error(error.localizedDescription)
                }
            }
            // In Library, delete object
            try! realm.safeWrite {
                target.isDeleted = true
            }
            return false
        }

        // Add To library
        let unread = getUnreadCount(for: .init(contentId: content.contentId, sourceId: content.sourceId), realm)
        try! realm.safeWrite {
            let obj = LibraryEntry()
            obj.content = content
            // Update Dates
            obj.lastOpened = .now
            obj.unreadCount = unread
            obj.lastUpdated = .now
            realm.add(obj, update: .modified)
        }

        // Get Ids
        let anilistId = content.trackerInfo["al"]

        // Run Addition Event
        guard let source, source.intents.contentEventHandler else {
            return true
        }
        
        Task {
            do {
                try await source.onContentsAddedToLibrary(ids: [ids.contentId])
            } catch {
                ToastManager.shared.info("Failed to Sync With \(source.name)")
                Logger.shared.error(error.localizedDescription)
            }
        }
        return true
    }

    func isInLibrary(content: StoredContent) -> Bool {
        let realm = try! Realm()

        return realm.objects(LibraryEntry.self).contains(where: { $0.id == content.id })
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

        guard let entry = realm.objects(LibraryEntry.self).where({ $0.id == entry }).first else { return }

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

        let objects = realm.objects(LibraryEntry.self).filter { ids.contains($0.id) }

        let ids = objects.compactMap { $0.content?.ContentIdentifier }
        let grouped = Dictionary(grouping: ids, by: { $0.sourceId })

        for (key, value) in grouped {
            let source = SourceManager.shared.getSource(id: key)
            guard let source, source.intents.contentEventHandler else { continue }
            Task {
                do {
                    try await source.onContentsRemovedFromLibrary(ids: value.map { $0.contentId })
                } catch {
                    ToastManager.shared.info("Failed to Sync With \(source.name)")
                }
            }
        }

        try! realm.safeWrite {
            realm.delete(objects)
        }
    }

    func moveToCollections(entries: Set<String>, cids: [String]) {
        let realm = try! Realm()

        let objects = realm.objects(LibraryEntry.self).filter { entries.contains($0.id) }
        try! realm.safeWrite {
            objects.forEach {
                $0.collections.removeAll()
                $0.collections.append(objectsIn: cids)
            }
        }
    }

    func clearUpdates(id: String) {
        let realm = try! Realm()

        guard let entry = realm.objects(LibraryEntry.self).first(where: { $0.id == id }) else {
            return
        }

        try! realm.safeWrite {
            entry.updateCount = 0
            entry.lastOpened = Date()
        }
    }

    func updateLastRead(forId id: String, _ realm: Realm? = nil) {
        let realm = try! realm ?? Realm()

        guard let entry = realm.objects(LibraryEntry.self).first(where: { $0.id == id }) else {
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
        // Get Max Read Chapter
        let maxRead = realm
            .objects(ProgressMarker.self)
            .where { $0.id == id.id }
            .first?
            .maxReadChapter ?? -1

        // Get Total Chapter Count
        let unread = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == id.contentId }
            .where { $0.sourceId == id.sourceId }
            .where { $0.number > maxRead }
            .distinct(by: [\.number])
            .count
        return unread
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

    func decrementUnreadCount(for id: String, _ realm: Realm? = nil) {
        let realm = try! realm ?? Realm()
        let target = realm
            .objects(LibraryEntry.self)
            .where { $0.content.id == id }
            .first

        guard let target else { return }
        try! realm.safeWrite {
            target.unreadCount -= 1
            target.lastRead = .now
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
