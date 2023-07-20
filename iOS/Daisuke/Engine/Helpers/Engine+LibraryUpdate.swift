//
//  Engine+LibraryUpdate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import RealmSwift
// MARK: - Fetch Library Update
extension DSK {
    func fetchLibraryUpdates() async -> Int {
        let engine = DSK.shared
        let sources = DataManager
            .shared
            .getSavedAndEnabledSources()
            .compactMap { engine.getSource(id: $0.id)  }
            .filter { $0.ablityNotDisabled(\.disableUpdateChecks) }

        // Fetch Update For Each Source
        let result = await withTaskGroup(of: Int.self) { group in

            for source in sources {
                group.addTask { [weak self] in
                    do {
                        let updateCount = try await self?.fetchUpdatesForSource(source: source)
                        return updateCount ?? 0
                    } catch {
                        Logger.shared.error("\(error)")
                    }
                    return 0
                }
            }

            var total = 0
            for await result in group {
                total += result
            }
            return total
        }

        UserDefaults.standard.set(Date(), forKey: STTKeys.LastFetchedUpdates)
        return result
    }
}


extension DSK {
    @MainActor
    private func fetchUpdatesForSource(source: JSCContentSource) async throws -> Int {
        let realm = try! await Realm()
        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        let skipConditions = Preferences.standard.skipConditions
        let validStatuses = [ContentStatus.ONGOING, .HIATUS, .UNKNOWN]
        var results = realm.objects(LibraryEntry.self)
            .where { $0.content != nil }
            .where { $0.dateAdded < date }
            .where { $0.content.sourceId == source.id }
            .where { $0.content.status.in(validStatuses) }

        // Flag Not Set to Reading Skip Condition
        if skipConditions.contains(.INVALID_FLAG) {
            results = results
                .where { $0.flag == .reading }
        }
        // Title Has Unread Skip Condition
        if skipConditions.contains(.HAS_UNREAD) {
            results = results
                .where { $0.unreadCount == 0 }
        }
        // Title Has No Markers, Has not been started
        if skipConditions.contains(.NO_MARKERS) {
            let ids = results.map(\.id) as [String]
            let startedTitles = realm
                .objects(ProgressMarker.self)
                .where { $0.id.in(ids) }
                .map(\.id) as [String]

            results = results
                .where { $0.id.in(startedTitles) }
        }
        let library = Array(results.freeze())
        var updateCount = 0
        Logger.shared.log("[\(source.id)] [Updates Checker] Updating \(library.count) titles")
        for entry in library {
            guard let contentId = entry.content?.contentId else {
                continue
            }

            // Fetch Chapters
            let chapters = try? await getChapters(for: contentId, with: source)
            var marked: [String] = []
            
            if source.intents.chapterSyncHandler {
                marked = (try? await source.getReadChapterMarkers(contentId: contentId)) ?? []
            }
            
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, contentId)
            // Calculate Update Count
            var filtered = chapters?
                .filter { $0.date > entry.lastUpdated }
                .filter { $0.date > entry.lastOpened }

            // Marked As Read on Source
            if !marked.isEmpty {
                filtered = filtered?
                    .filter { !marked.contains($0.chapterId) }
            }

            // Already Fetched on Source
            if let lastFetched, let lastFetchedUpdatedIndex = chapters?
                .first(where: { $0.chapterId == lastFetched.chapterId })?
                .index
            {
                filtered = filtered?
                    .filter { $0.index < lastFetchedUpdatedIndex }
            }
            var updates = filtered?.count ?? 0

            let checkLinked = UserDefaults.standard.bool(forKey: STTKeys.CheckLinkedOnUpdateCheck)
            var linkedHasUpdate = false
            if checkLinked {
                let lowerChapterLimit = filtered?.sorted(by: { $0.number < $1.number }).last?.number ?? lastFetched?.number
                linkedHasUpdate = await linkedHasUpdates(id: entry.id, lowerChapterLimit: lowerChapterLimit)
                if linkedHasUpdate, updates == 0 { updates += 1 }
            }
            // No Updates Return 0
            if updates == 0 {
                continue
            }
            
            guard let entry = entry.thaw() else {
                continue
            }

            // New Chapters Found, Update Library Entry Object
            try! realm.safeWrite {
                entry.lastUpdated = chapters?.sorted(by: { $0.date > $1.date }).first?.date ?? Date()
                entry.updateCount += updates
                if !entry.linkedHasUpdates, linkedHasUpdate {
                    entry.linkedHasUpdates = true
                }
            }

            guard let chapters = chapters else {
                DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)
                continue
            }
            let sourceId = source.id
            Task {
                let stored = chapters.map { $0.toStoredChapter(withSource: sourceId) }
                DataManager.shared.storeChapters(stored)
                DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)
            }

            updateCount += updates
        }

        return updateCount
    }

    private func getChapters(for id: String, with source: JSCContentSource) async throws -> [DSKCommon.Chapter] {
        let shouldUpdateProfile = UserDefaults.standard.bool(forKey: STTKeys.UpdateContentData)

        if shouldUpdateProfile {
            let profile = try? await source.getContent(id: id)
            if let stored = try? profile?.toStoredContent(withSource: source.id) {
                DataManager.shared.storeContent(stored)
            }

            if let chapters = profile?.chapters {
                return chapters
            }
        }

        let chapters = try await source.getContentChapters(contentId: id)
        return chapters
    }

    func linkedHasUpdates(id: String, lowerChapterLimit: Double?) async -> Bool {
        let linked = DataManager.shared.getLinkedContent(for: id)

        for title in linked {
            guard let source = DSK.shared.getSource(id: title.sourceId) else { continue }
            guard let chapters = try? await source.getContentChapters(contentId: title.contentId) else { continue }
            var marked: [String] = []
            
            if source.intents.chapterSyncHandler {
                marked = (try? await source.getReadChapterMarkers(contentId: title.contentId)) ?? []
            }
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, title.contentId)
            var filtered = chapters

            if let lowerChapterLimit {
                filtered = filtered
                    .filter { $0.number > lowerChapterLimit }
            }

            // Marked As Read on Source
            if !marked.isEmpty {
                filtered = filtered
                    .filter { !marked.contains($0.chapterId) }
            }

            // Already Fetched on Source
            if let lastFetched, let lastFetchedUpdatedIndex = chapters
                .first(where: { $0.chapterId == lastFetched.chapterId })?
                .index
            {
                filtered = filtered
                    .filter { $0.index < lastFetchedUpdatedIndex }
            }

            if !filtered.isEmpty { return true }
        }
        return false
    }
}
