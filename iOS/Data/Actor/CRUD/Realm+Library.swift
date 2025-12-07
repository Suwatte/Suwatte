//
//  Realm+Library.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//
import Foundation
import RealmSwift

extension RealmActor {
    private func getLibraryEntry(for id: String) -> LibraryEntry? {
        getObject(of: LibraryEntry.self, with: id)
    }

    func getLibraryEntries(for source: String) -> [LibraryEntry] {
        realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == source }
            .where { !$0.isDeleted }
            .freeze()
            .toArray()
    }

    func getDanglingLibraryHighlights(with known: [String]) -> [String: [TaggedHighlight]] {
        let entries = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil }
            .where { !$0.content.sourceId.in(known) }
            .where { !$0.isDeleted }
            .freeze()
            .toArray()
            .map {
                TaggedHighlight(from: $0.content!.toHighlight(), with: $0.content!.sourceId)
            }

        return Dictionary(grouping: entries, by: \.sourceID)
    }
}

extension RealmActor {
    func setReadingFlag(for id: String, to flag: LibraryFlag) async {
        let target = getLibraryEntry(for: id)
        guard let target else { return }

        await operation {
            target.flag = flag
        }

        guard let id = target.content?.contentId,
              let sourceId = target.content?.sourceId,
              let source = await DSK.shared.getSource(id: sourceId),
              source.intents.contentEventHandler
        else {
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

        await operation {
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
        if let target = getObject(of: LibraryEntry.self, with: ids.id), !target.isDeleted {
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
            await operation {
                target.isDeleted = true
            }

            await unlinkAll(for: ids.id)
            return false
        }

        // Add To library
        let unread = getUnreadCount(for: .init(contentId: ids.contentId, sourceId: ids.sourceId))
        await operation {
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

        await operation {
            entry.collections.removeAll()
        }
    }

    func toggleCollection(for id: String, withId cid: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        await operation {
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

        await operation {
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
        await operation {
            for object in objects {
                object.collections.removeAll()
                object.collections.append(objectsIn: cids)
            }
        }
    }

    func clearUpdates(id: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        await operation {
            entry.updateCount = 0
            entry.lastOpened = .now
        }
    }

    func updateLastRead(forId id: String) async {
        guard let entry = getLibraryEntry(for: id) else {
            return
        }

        await operation {
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
        // Get Max Read Chapter Order key
        let readChapters = Set(getFrozenContentMarkers(for: id).map { $0.chapter!.chapterOrderKey })

        // Get Total Chapter Count
        let unreadChapters = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == id.contentId }
            .where { $0.sourceId == id.sourceId }
            .freeze()
            .toArray()
            .filter { !readChapters.contains($0.chapterOrderKey) }
            .distinct(by: \.number)
            .map { $0.toThreadSafe() }

        let filtered = STTHelpers.filterChapters(unreadChapters, with: id)
        return filtered.count
    }

    func updateUnreadCount(for id: ContentIdentifier) async {
        let target = getLibraryEntry(for: id.id)

        guard let target else { return }

        let count = getUnreadCount(for: id)
        await operation {
            target.unreadCount = count
        }
    }

    func decrementUnreadCount(for id: String) async {
        let target = getLibraryEntry(for: id)

        guard let target else { return }
        await operation {
            target.unreadCount = max(target.unreadCount - 1, 0)
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

        let currentCollections = target.collections.toArray()
        let fixed = currentCollections.filter { collections.contains($0) }
        await operation {
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
        getLibraryEntry(for: ContentIdentifier(contentId: c, sourceId: s).id) != nil
    }

    func contentSavedForLater(s: String, c: String) -> Bool {
        getReadLater(for: ContentIdentifier(contentId: c, sourceId: s).id) != nil
    }
}
