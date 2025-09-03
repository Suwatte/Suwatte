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
        let sources = await getSourcesForUpdateCheck()

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

        return result
    }
}

extension DSK {
    private func fetchUpdatesForSource(source: AnyContentSource) async throws -> Int {
        let actor = await RealmActor.shared()
        let library = await actor.getTitlesPendingUpdate(source.id)
        Logger.shared.log("[\(source.id)] [Updates Checker] Updating \(library.count) titles")

        let updates = await withTaskGroup(of: Int.self, body: { group in
            for entry in library {
                group.addTask { [weak self] in
                    await self?.getUpdates(for: entry, source: source) ?? 0
                }
            }

            var updates = 0
            for await result in group {
                updates += result
            }

            return updates
        })

        return updates
    }

    private func getUpdates(for entry: LibraryEntry, source: AnyContentSource) async -> Int {
        guard let contentId = entry.content?.contentId else {
            return 0
        }

        let actor = await RealmActor.shared()

        // Fetch Chapters
        let chapters = try? await getChapters(for: contentId, with: source)

        guard var chapters else { return 0 }
        chapters = STTHelpers.filterChapters(chapters, with: .init(contentId: contentId, sourceId: source.id))

        var marked: [String] = []

        if source.intents.progressSyncHandler ?? false {
            do {
                let data = try await source.getProgressState(for: contentId)
                if let ids = data.readChapterIds {
                    marked.append(contentsOf: ids)
                }
            } catch {
                Logger.shared.error(error, "(getProgressState)-\(source.id)")
            }
        }

        let lastFetched = await actor.getLatestStoredChapter(source.id, contentId)
        // Calculate Update Count
        var filtered = chapters

        // Marked As Read on Source
        if !marked.isEmpty {
            filtered = filtered
                .filter { !marked.contains($0.chapterId) }
        }

        // Already Fetched on Source
        if let lastFetched, let target = filtered.first(where: { $0.chapterId == lastFetched.chapterId }) {
            filtered = filtered
                .filter { $0.index < target.index }
        }

        var updates = filtered.count

        let checkLinked = UserDefaults.standard.bool(forKey: STTKeys.CheckLinkedOnUpdateCheck)
        var linkedHasUpdate = false
        if checkLinked {
            let lowerChapterLimit = filtered.map(\.orderKey).max() ?? lastFetched?.chapterOrderKey ?? 0
            linkedHasUpdate = await linkedHasUpdates(id: entry.id, lowerChapterLimit: lowerChapterLimit)
            if linkedHasUpdate, updates == 0 { updates += 1 }
        }
        // No Updates Return 0
        if updates == 0 {
            return 0
        }

        await actor.didFindUpdates(for: entry.id, count: updates, date: .now, onLinked: linkedHasUpdate)

        let sourceId = source.id
        let stored = chapters.map { $0.toStoredChapter(sourceID: sourceId, contentID: entry.content!.contentId) }
        await actor.storeChapters(stored)
        await actor.updateUnreadCount(for: entry.content!.ContentIdentifier)

        return updates
    }

    private func getChapters(for id: String, with source: AnyContentSource) async throws -> [DSKCommon.Chapter] {
        let shouldUpdateProfile = UserDefaults.standard.bool(forKey: STTKeys.UpdateContentData)

        if shouldUpdateProfile, let chapters = try await updateProfile(for: id, with: source) {
            return chapters
        }

        var chapters = try await source.getContent(id: id).chapters ?? []
        if chapters.isEmpty {
            chapters = try await source.getContentChapters(contentId: id)
        }
        return chapters
    }

    private func updateProfile(for id: String, with source: AnyContentSource) async throws -> [DSKCommon.Chapter]? {
        do {
            let profile = try await source
                .getContent(id: id)
            let content = try profile
                .toStoredContent(with: .init(contentId: id, sourceId: source.id))
            let manager = await RealmActor.shared()
            await manager.storeContent(content)
            return profile.chapters
        } catch {
            Logger.shared.error(error, "Engine")
        }
        return nil
    }

    func linkedHasUpdates(id: String, lowerChapterLimit: Double?) async -> Bool {
        let actor = await RealmActor.shared()
        let linkedTitles = await actor.getLinkedContent(for: id)

        let result = await withTaskGroup(of: Bool.self, body: { group in
            for title in linkedTitles {
                group.addTask { [unowned self] in
                    await checkLinked(title: title, min: lowerChapterLimit)
                }
            }

            var value = false
            for await result in group {
                if !value, result {
                    value = true
                }
            }
            return value
        })
        return result
    }

    func checkLinked(title: StoredContent, min: Double?) async -> Bool {
        let actor = await RealmActor.shared()
        guard let source = await DSK.shared.getSource(id: title.sourceId) else { return false }

        var chapters = try? await source.getContent(id: title.contentId).chapters
        if chapters != nil && chapters!.isEmpty {
            chapters = try? await source.getContentChapters(contentId: title.contentId)
        }

        guard let chapters else { return false }
        var marked: [String] = []

        if Task.isCancelled { return false }
        if source.intents.progressSyncHandler ?? false {
            do {
                let data = try await source.getProgressState(for: title.contentId)
                if let ids = data.readChapterIds {
                    marked.append(contentsOf: ids)
                }
            } catch {
                Logger.shared.error(error, "(getProgressState)-\(source.id)")
            }
        }

        let lastFetched = await actor.getLatestStoredChapter(source.id, title.contentId)
        if Task.isCancelled { return false }
        var filtered = STTHelpers.filterChapters(chapters, with: .init(contentId: title.contentId, sourceId: title.sourceId))

        if let min {
            filtered = filtered
                .filter { $0.orderKey > min }
        }

        // Marked As Read on Source
        if !marked.isEmpty {
            filtered = filtered
                .filter { !marked.contains($0.chapterId) }
        }

        // Already Fetched on Source
        if let lastFetched {
            filtered = filtered
                .filter { $0.orderKey < lastFetched.chapterOrderKey }
        }

        return !filtered.isEmpty
    }
}
