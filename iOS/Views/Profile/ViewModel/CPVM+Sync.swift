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
                              let entry = try await tracker.getTrackItem(id: value).entry else {
                            return (tracker.id, 0)
                        }
                        
                        let originMaxReadChapter = entry.progress.lastReadChapter
                        let originMaxVolume = entry.progress.lastReadVolume ?? 0
                        return (tracker.id, ThreadSafeChapter.orderKey(volume: originMaxVolume, number: originMaxReadChapter))
                    } catch {
                        Logger.shared.error(error, tracker.id)
                        return (tracker.id, 0)
                    }
                }
            }

            var markers: [String: Double] = [:]

            for await(key, chapterKey) in group {
                markers[key] = chapterKey
            }
            return markers
        })

        // Source Chapter Sync Handler
        var sourceOriginHighestRead: Double = 0
        if source.intents.chapterSyncHandler {
            do {
                let chapterIds = try await source.getReadChapterMarkers(contentId: entry.id)
                sourceOriginHighestRead = chapters
                    .filter { chapterIds.contains($0.chapterId) }
                    .map { ThreadSafeChapter.orderKey(volume: $0.volume, number: $0.number) }
                    .max() ?? 0
            } catch {
                Logger.shared.error(error, source.id)
            }
        }

        // Prepare the Highest Read Chapter Number
        let localHighestRead = await actor.getMaxReadChapterOrderKey(id: identifier.id)
        let originHighestRead = Array(markers.values).max() ?? 0
        let maxRead = max(localHighestRead, originHighestRead, sourceOriginHighestRead)

        // Max Read is 0, do not sync
        guard maxRead != 0 else { return }
        let (maxReadVolume, maxReadChapter) = ThreadSafeChapter.vnPair(from: maxRead)

        // Update Origin Value if outdated
        await withTaskGroup(of: Void.self, body: { group in
            for (key, value) in markers {
                guard let tracker = await DSK.shared.getTracker(id: key), maxRead > value, let entryId = matches[key] else { continue }
                group.addTask {
                    guard let _ = try? await tracker.getAuthenticatedUser() else { return }

                    do {
                        try await tracker.didUpdateLastReadChapter(id: entryId, progress: .init(chapter: maxReadChapter, volume: maxReadVolume))
                    } catch {
                        Logger.shared.error(error, tracker.id)
                    }
                }
            }
        })

        // Update Local Value if outdated, sources are notified if they have the Chapter Event Handler
        guard maxRead != localHighestRead else { return }
        let chaptersToMark = Set(chapters.map(\.chapterOrderKey)).filter { $0 <= maxRead }
        let linked = await actor.getLinkedContent(for: identifier.id)
        await actor.markChaptersByNumber(for: identifier, chapters: chaptersToMark)
        await withTaskGroup(of: Void.self, body: { group in
            for link in linked {
                group.addTask {
                    await actor
                        .markChaptersByNumber(for: link.ContentIdentifier, chapters: chaptersToMark)
                }
            }
        })
    }
}
