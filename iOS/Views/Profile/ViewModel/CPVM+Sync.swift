//
//  CPVM+Sync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func handleSync() async {
        await animate { [weak self] in
            self?.syncState = .syncing
        }
        await syncWithAllParties()
        await animate { [weak self] in
            self?.syncState = .done
        }
    }

    func syncWithAllParties() async {
        let actor = await RealmActor.shared()
        let identifier = STTIDPair
        // gets tracker matches in a [TrackerID:EntryID] format
        let matches: [String: String] = await actor.getTrackerLinks(for: identifier.id)

        // Get A Dictionary representing the trackers and the current max read chapter on each tracker
        typealias Marker = (String, Double)
        let markers = await withTaskGroup(of: Marker.self, body: { group in

            for (key, value) in matches {
                // Get Tracker To handle
                guard let tracker = await DSK.shared.getTracker(id: key) else {
                    continue
                }

                group.addTask {
                    do {
                        guard let _ = try await tracker.getAuthenticatedUser(),
                              let entry = try await tracker.getTrackItem(id: value).entry
                        else {
                            return (tracker.id, 0)
                        }

                        let originMaxReadChapter = entry.progress.lastReadChapter
                        return (tracker.id, originMaxReadChapter)
                    } catch {
                        Logger.shared.error(error, tracker.id)
                        return (tracker.id, 0)
                    }
                }
            }

            var markers: [String: Double] = [:]

            for await(key, originMaxReadChapter) in group {
                markers[key] = originMaxReadChapter
            }
            return markers
        })

        let chapters = chapterMap[identifier.id]?.filtered
        guard let chapters else { return }
        // Source Chapter Sync Handler
        var sourceOriginHighestRead: Double = 0
        if source.intents.progressSyncHandler ?? false, let state = sourceProgressState {
            var chapterListMax: Double = 0
            var markStateMax: Double = 0
            if let readIds = state.readChapterIds {
                chapterListMax = chapters
                    .filter { readIds.contains($0.chapterId) }
                    .map(\.number)
                    .max() ?? 0
            }

            if let markState = state.markAllBelowAsRead {
                markStateMax = markState.chapterNumber
            }
            sourceOriginHighestRead = max(chapterListMax, markStateMax)
        }

        // Switch to chapters for this portion.
        // Prepare the Highest Read Chapter Number
        let localHighestRead = ThreadSafeChapter.vnPair(from: await actor.getMaxReadChapterOrderKey(id: identifier.id)).1
        let originHighestRead = Array(markers.values).max() ?? 0
        let maxReadChapter = max(localHighestRead, originHighestRead, sourceOriginHighestRead)

        // Max Read is 0, do not sync
        guard maxReadChapter != 0 else { return }

        // Update Origin Value if outdated
        await withTaskGroup(of: Void.self, body: { group in
            for (key, value) in markers {
                guard let tracker = await DSK.shared.getTracker(id: key), maxReadChapter > value, let entryId = matches[key] else { continue }
                group.addTask {
                    guard let _ = try? await tracker.getAuthenticatedUser() else { return }

                    do {
                        try await tracker.didUpdateLastReadChapter(id: entryId, progress: .init(chapter: maxReadChapter, volume: nil))
                    } catch {
                        Logger.shared.error(error, tracker.id)
                    }
                }
            }
        })

        // Update Local Value if outdated, sources are notified if they have the Chapter Event Handler
        guard maxReadChapter != localHighestRead else { return }
        let chaptersToMark = chapters.filter { $0.number <= maxReadChapter }.map(\.chapterOrderKey)
        let linked = await actor.getLinkedContent(for: identifier.id)
        await actor.markChaptersByNumber(for: identifier, chapters: Set(chaptersToMark))
        await withTaskGroup(of: Void.self, body: { group in
            for link in linked {
                group.addTask {
                    await actor
                        .markChaptersByNumber(for: link.ContentIdentifier, chapters: Set(chaptersToMark))
                }
            }
        })
    }
}
