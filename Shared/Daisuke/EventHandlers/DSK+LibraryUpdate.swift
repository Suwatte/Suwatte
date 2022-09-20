//
//  DSK+LibraryUpdate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-28.
//

import Foundation
import RealmSwift

extension DaisukeEngine {
    @MainActor
    func handleBackgroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    @MainActor
    func handleForegroundLibraryUpdate() async -> Int {
        return await fetchLibaryUpdates()
    }

    @MainActor
    private func fetchLibaryUpdates() async -> Int {
        let updateCounts = await getSources().asyncMap { source -> Int in
            (try? await fetchUpdatesForSource(source: source)) ?? 0
        }
        UserDefaults.standard.set(Date(), forKey: STTKeys.LastFetchedUpdates)

        return updateCounts.reduce(0, +)
    }

    @MainActor
    private func fetchUpdatesForSource(source: ContentSource) async throws -> Int {
        let realm = try! await Realm()

        let date = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as! Date
        // Filter out titles that may have been recently added
        let library = realm.objects(LibraryEntry.self)
            .where { $0.dateAdded < date &&
                $0.content.sourceId == source.id &&
                $0.content.status == .ONGOING &&
                ($0.flag == .unknown || $0.flag == .reading)
            }
            .map { $0 } as [LibraryEntry]

        var updateCount = 0
        print("[DAISUKE] [UPDATER] [\(source.id)] \(library.count) Titles Matching")
        for entry in library {
            guard let contentId = entry.content?.contentId else {
                continue
            }

            // Fetch Chapters
            let chapters = try? await source.getContentChapters(contentId: contentId)
            let marked = try? await source.getReadChapterMarkers(for: contentId)

            // Calculate Update Count
            let updates = chapters?
                .filter { $0.date > entry.lastUpdated }
                .filter { $0.date > entry.lastOpened }
                .filter { !(marked?.contains($0.chapterId) ?? false) }
                .count ?? 0

            // No Updates Return 0
            if updates == 0 {
                continue
            }

            // New Chapters Found, Update Library Entry Object
            try! realm.safeWrite {
                entry.lastUpdated = chapters?.sorted(by: { $0.date > $1.date }).first?.date ?? Date()
                entry.updateCount += updates
            }

            updateCount += updates
        }

        return updateCount
    }
}
