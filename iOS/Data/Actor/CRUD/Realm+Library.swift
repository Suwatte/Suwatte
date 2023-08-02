//
//  Realm+Library.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//
import RealmSwift
import Foundation

extension RealmActor {
    
    func getLibraryEntry(for id: String) -> LibraryEntry? {
        realm
            .objects(LibraryEntry.self)
            .where { $0.id == id }
            .first
    }
    
    func setReadingFlag(for id: String, to flag: LibraryFlag) async {
        let target = getLibraryEntry(for: id)
        guard let target else { return }

        try! await realm.asyncWrite {
            target.flag = flag
        }

        guard let id = target.content?.contentId,
              let sourceId = target.content?.sourceId,
              let source = await DSK.shared.getSource(id: sourceId),
              source.intents.contentEventHandler else {
            return
        }
        Task {
            do {
                try await source.onContentsReadingFlagChanged(ids: [id], flag: flag)
            } catch {
                ToastManager.shared.error(error)
                Logger.shared.error(error)
            }
        }
    }

    func bulkSetReadingFlag(for ids: Set<String>, to flag: LibraryFlag) async {

        let targets = realm
            .objects(LibraryEntry.self)
            .where { $0.id.in(ids) }

        try! await realm.asyncWrite {
            for target in targets {
                target.flag = flag
            }
        }

        let sourceIds = Set(targets.compactMap { $0.content?.sourceId })
        for id in sourceIds {
            let source = await DSK.shared.getSource(id: id)

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
    func toggleLibraryState(for ids: ContentIdentifier) async -> Bool {
        let source = await DSK.shared.getSource(id: ids.sourceId)
        if let target = realm.objects(LibraryEntry.self).first(where: { $0.id == ids.id }) {
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
        let unread = getUnreadCount(for: .init(contentId: ids.contentId, sourceId: ids.sourceId))
        try! realm.safeWrite {
            let obj = LibraryEntry()
            obj.content = getStoredContent(ids.id)
            // Update Dates
            obj.lastOpened = .now
            obj.unreadCount = unread
            obj.lastUpdated = .now
            realm.add(obj, update: .modified)
        }

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

    func isInLibrary(id: String) -> Bool {
         !realm
            .objects(LibraryEntry.self)
            .where { $0.id == id }
            .isEmpty
    }

    // MARK: Collections

    func clearCollections(for id: String) async {
        
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        try! await realm.asyncWrite {
            entry.collections.removeAll()
        }
    }

    func toggleCollection(for id: String, withId cid: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        try! await realm.asyncWrite {
            if entry.collections.contains(cid) {
                entry.collections.remove(at: entry.collections.firstIndex(of: cid)!)
            } else {
                entry.collections.append(cid)
            }
        }
    }

    func batchRemoveFromLibrary(with ids: Set<String>) async {
        let objects = realm
            .objects(LibraryEntry.self)
            .where { $0.id.in(ids) }

        let ids = objects.compactMap { $0.content?.ContentIdentifier }

        try! await realm.asyncWrite {
            for object in objects {
                object.isDeleted = true
            }
        }
        
        let grouped = Dictionary(grouping: ids, by: { $0.sourceId })

        for (key, value) in grouped {
            let source = await DSK.shared.getSource(id: key)
            guard let source, source.intents.contentEventHandler else { continue }
            Task {
                do {
                    try await source.onContentsRemovedFromLibrary(ids: value.map { $0.contentId })
                } catch {
                    ToastManager.shared.info("Failed to Sync With \(source.name)")
                }
            }
        }
    }

    func moveToCollections(entries: Set<String>, cids: [String]) async {
        let objects = realm.objects(LibraryEntry.self)
            .where { $0.id.in(entries) }
        try! await realm.asyncWrite {
            objects.forEach {
                $0.collections.removeAll()
                $0.collections.append(objectsIn: cids)
            }
        }
    }

    func clearUpdates(id: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        try! await realm.asyncWrite {
            entry.updateCount = 0
            entry.lastOpened = .now
        }
    }

    func updateLastRead(forId id: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        try! await realm.asyncWrite {
            entry.lastRead = .now
        }
    }

    func getEntriesToBeUpdated(sourceId: String) -> [LibraryEntry] {
        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        // Filter out titles that may have been recently added
        return realm.objects(LibraryEntry.self)
            .where { $0.dateAdded < date && $0.content.sourceId == sourceId && $0.content.status == .ONGOING }
            .freeze()
            .toArray()
    }

    func getUnreadCount(for id: ContentIdentifier) -> Int {
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

    func updateUnreadCount(for id: ContentIdentifier) async {

        let target = realm
            .objects(LibraryEntry.self)
            .where { $0.content.contentId == id.contentId }
            .where { $0.content.sourceId == id.sourceId }
            .first

        guard let target else { return }

        let count = getUnreadCount(for: id)
        try! await realm.asyncWrite {
            target.unreadCount = count
        }
    }

    func decrementUnreadCount(for id: String) async {
        let target = realm
            .objects(LibraryEntry.self)
            .where { $0.content.id == id }
            .first

        guard let target else { return }
        try! await realm.asyncWrite {
            target.unreadCount -= 1
            target.lastRead = .now
        }
    }
    
    func fetchAndPruneLibraryEntry(for id: String) async -> LibraryEntry? {
        guard let target = getLibraryEntry(for: id) else {
            return nil
        }
        
        let collections = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .map(\.id)

        
        let currentCollections = target.collections
        let fixed = currentCollections.filter { collections.contains($0) }
        
        try! await realm.asyncWrite {
            target.collections.removeAll()
            target.collections.append(objectsIn: fixed)
        }
        
        
        return target
            .freeze()
    }
    
    func getLibraryCollections() -> [LibraryCollection] {
        realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .freeze()
            .toArray()
    }
}

extension RealmActor {
    func contentInLibrary(s: String, c: String) -> Bool {

        return !realm
            .objects(LibraryEntry.self)
            .where { $0.content.contentId == c && $0.content.sourceId == s }
            .isEmpty
    }

    func contentSavedForLater(s: String, c: String) -> Bool {

        return !realm
            .objects(ReadLater.self)
            .where { $0.content.contentId == c && $0.content.sourceId == s }
            .isEmpty
    }
}