//
//  DSK+LibraryUpdate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-28.
//

import Foundation
import RealmSwift

extension DaisukeEngine {
    func handleBackgroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    func handleForegroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    private func fetchLibaryUpdates() async -> Int {
        let sources = getSources()
        let result = await withTaskGroup(of: Int.self, body: { group in

            for source in sources {
                group.addTask {
                    let count = try? await self.fetchUpdatesForSource(source: source)
                    return count ?? 0
                }
            }

            var total = 0
            for await result in group {
                total += result
            }
            return total
        })
        UserDefaults.standard.set(Date(), forKey: STTKeys.LastFetchedUpdates)
        return result
    }

    @MainActor
    private func fetchUpdatesForSource(source: DaisukeContentSource) async throws -> Int {
        let realm = try! Realm(queue: nil)
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
            let startedTitles = realm
                .objects(ChapterMarker.self)
                .where { $0.completed == true }
                .where { $0.chapter != nil }
                .where { $0.chapter.sourceId == source.id }
                .distinct(by: [\.chapter?.sourceId, \.chapter?.contentId])
                .map { ContentIdentifier(contentId: $0.chapter!.contentId, sourceId: $0.chapter!.sourceId).id } as [String]

            results = results
                .where { $0._id.in(startedTitles) }
        }
        let library = results.map { $0 } as [LibraryEntry]
        var updateCount = 0
        Logger.shared.log("[DAISUKE] [UPDATER] [\(source.id)] \(library.count) Titles Matching")
        for entry in library {
            guard let contentId = entry.content?.contentId else {
                continue
            }

            // Fetch Chapters
            let chapters = try? await getChapters(for: contentId, with: source)
            let marked = try? await(source as? DSK.LocalContentSource)?.getReadChapterMarkers(for: contentId)
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, contentId)
            // Calculate Update Count
            var filtered = chapters?
                .filter { $0.date > entry.lastUpdated }
                .filter { $0.date > entry.lastOpened }

            // Marked As Read on Source
            if let marked {
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
                linkedHasUpdate = await linkedHasUpdates(id: entry._id, lowerChapterLimit: lowerChapterLimit)
                if linkedHasUpdate, updates == 0 { updates += 1 }
            }
            // No Updates Return 0
            if updates == 0 {
                continue
            }

            // New Chapters Found, Update Library Entry Object
            try! realm.safeWrite {
                entry.lastUpdated = chapters?.sorted(by: { $0.date > $1.date }).first?.date ?? Date()
                entry.updateCount += updates
                if !entry.linkedHasUpdates, linkedHasUpdate {
                    entry.linkedHasUpdates = true
                }
                // Update Chapters
                let stored = chapters?
                    .map { $0.toStoredChapter(withSource: source.id) }
                if let stored {
                    realm.add(stored, update: .modified)
                }
            }

            // Update Unread Count
            DataManager.shared.updateUnreadCount(for: entry.content!.ContentIdentifier, realm)

            updateCount += updates
        }

        return updateCount
    }

    private func getChapters(for id: String, with source: DaisukeContentSource) async throws -> [DSKCommon.Chapter] {
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

    @MainActor
    func linkedHasUpdates(id: String, lowerChapterLimit: Double?) async -> Bool {
        let linked = DataManager.shared.getLinkedContent(for: id)

        for title in linked {
            guard let source = DaisukeEngine.shared.getSource(with: title.sourceId) else { continue }
            guard let chapters = try? await source.getContentChapters(contentId: title.contentId) else { continue }
            let marked = try? await(source as? DSK.LocalContentSource)?.getReadChapterMarkers(for: title.contentId)
            let lastFetched = DataManager.shared.getLatestStoredChapter(source.id, title.contentId)
            var filtered = chapters

            if let lowerChapterLimit {
                filtered = filtered
                    .filter { $0.number > lowerChapterLimit }
            }

            // Marked As Read on Source
            if let marked {
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
