//
//  CPV+ViewModel.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-06.
//

import Foundation
import RealmSwift
import SwiftUI
import UIKit

extension ProfileView {
    // TODO: Rework this, complicated mess that could be made 10x Simpler
    // Remove Realm Objects?
    final class ViewModel: ObservableObject {
        @Published var entry: DaisukeEngine.Structs.Highlight
        var source: DaisukeEngine.ContentSource
        
        @Published var content: DSKCommon.Content = .placeholder
        @Published var loadableContent: Loadable<Bool> = .idle
        var storedContent: StoredContent {
            try! content.toStoredContent(withSource: source)
        }
        
        @Published var chapters: Loadable<[StoredChapter]> = .idle
        @Published var working = false
        @Published var linkedHasUpdate = false

        @Published var presentCollectionsSheet = false
        @Published var presentTrackersSheet = false
        @Published var presentSafariView = false
        @Published var presentBookmarksSheet = false
        @Published var syncState = SyncState.idle
        @Published var lastReadMarker: ChapterMarker?
        @Published var actionState: ActionState = .init(state: .none)

        @Published var threadSafeChapters: [DSKCommon.Chapter]?
        var notificationToken: NotificationToken?
        var syncTask: Task<Void, Error>?
        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: DaisukeEngine.ContentSource) {
            self.entry = entry
            self.source = source
        }

        @Published var selection: String?
        deinit {
            self.notificationToken?.invalidate()
        }
    }
}

extension ProfileView.ViewModel {
    func loadContentFromNetwork() async {
        do {
            // Fetch From JS
            let parsed = try await source.getContent(id: entry.id)
            await MainActor.run(body: {
                self.content = parsed
                self.loadableContent = .loaded(true)
                self.working = false
            })
            
            do {
                let stored = try parsed.toStoredContent(withSource: source)
                print(stored._id, stored.sourceId, stored.cover)
                DataManager.shared.storeContent(stored)
            } catch {
                print("Storage Error" ,error)
            }
//            Task {
//                await self.loadChapters(parsed.chapters)
//            }
        } catch {
            await MainActor.run(body: {
                if loadableContent.LOADED {
                    ToastManager.shared.setError(msg: "Failed to Update Profile")
                } else {
                    loadableContent = .failed(error)
                }
                working = false
            })
        }
    }

    func loadChapters(_ parsedChapters: [DSKCommon.Chapter]? = nil) async {
        await MainActor.run(body: {
            working = true
        })
        await MainActor.run(body: {
            threadSafeChapters = parsedChapters
        })
        if let chapters = parsedChapters {
            let stored = chapters.map { $0.toStoredChapter(withSource: source) }.sorted(by: { $0.index < $1.index })
            DataManager.shared.storeChapters(stored)
            self.chapters = .loaded(stored)
            working = false

        } else {
            do {
                let parsedChapters = try await source.getContentChapters(contentId: entry.id)
                await MainActor.run(body: {
                    threadSafeChapters = parsedChapters
                })
                let stored = parsedChapters.map { $0.toStoredChapter(withSource: source) }
                DataManager.shared.storeChapters(stored)
//
                let unmanaged = parsedChapters.map { $0.toStoredChapter(withSource: source) }

                await UIView.animate(withDuration: 0.1) { [weak self] in
                    self?.chapters = .loaded(unmanaged)
                    self?.working = false
                } completion: { complete in
                    if !complete { return }
                }
            } catch {
                if chapters.LOADED {
                    ToastManager.shared.setError(msg: "Failed to Fetch Chapters")
                    return
                } else {
                    chapters = .failed(error)
                }
                working = false
                ToastManager.shared.setError(error: error)
            }
        }

        if chapters.LOADED {
            DataManager.shared.clearUpdates(id: sttIdentifier().id)
            Task {
                await handleSync()
                await getMarkers()
                try await handleAnilistSync()
            }
        }
    }

    func removeNotifier() {
        notificationToken?.invalidate()
        notificationToken = nil
    }

    @MainActor
    func getMarkers() {
        let realm = try! Realm()

        notificationToken = realm
            .objects(ChapterMarker.self)
            .where { $0.chapter.contentId == entry.id }
            .where { $0.chapter.sourceId == source.id }
            .where { $0.dateRead != nil }
            .sorted(by: \.dateRead, ascending: false)
            .observe { collection in
                switch collection {
                case let .initial(results):
                    self.lastReadMarker = results.first
                case let .update(results, _, _, _):
                    self.lastReadMarker = results.first
                case let .error(error):
                    ToastManager.shared.setError(error: error)
                }

                self.calculateActionState()
            }
    }

    func calculateActionState() {
        guard let chapters = chapters.value else {
            actionState = .init(state: .none)
            return
        }
        guard content.contentId == entry.contentId else {
            return
        }
        guard let marker = lastReadMarker, let chapter = marker.chapter else {
            // Marker DNE, user has not started reading
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: chapter, marker: nil)
                return
            }
            actionState = .init(state: .none)
            return
        }

        if !marker.completed {
            // Marker Exists, series has not been complted, resume
            actionState = .init(state: .resume, chapter: marker.chapter, marker: (marker.progress, marker.dateRead))
            return
        }

        // Series has been completed

        // Get current chapter index
        guard var index = chapters.firstIndex(where: { $0.chapterId == chapter.chapterId }) else {
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: chapter, marker: nil)
                return
            }
            actionState = .init(state: .none)
            return
        }

        // Current Index is equal to that of the last available chapter
        // Set action state to re-read
        // marker is nil to avoid progress display
        if index == 0 {
            if content.status == .COMPLETED, let chapter = chapters.last {
                actionState = .init(state: .restart, chapter: chapter, marker: nil)
                return
            }
            actionState = .init(state: .reRead, chapter: marker.chapter, marker: nil)
            return
        }

        // index not 0, decrement, sourceIndex moves inverted
        index -= 1
        actionState = .init(state: .upNext, chapter: chapters.get(index: index), marker: nil)
    }

    func loadContentFromDatabase() async {
        await MainActor.run(body: {
            withAnimation {
                self.loadableContent = .loading
            }
        })

        let target = DataManager.shared.getStoredContent(source.id,entry.id)
        
        if let target = target {
            do {
                let c = try target.toDSKContent()
                await MainActor.run(body: {
                    content = c
                    loadableContent = .loaded(true)
                })
                
            } catch {
                
            }
            
        }

        Task {
            await loadContentFromNetwork()
        }
    }

    func sttIdentifier() -> DaisukeEngine.Structs.SuwatteContentIdentifier {
        .init(contentId: entry.id, sourceId: source.id)
    }

    func checkForUpdatesOnLinked() {}
}

extension ProfileView.ViewModel {
    enum SyncState: Hashable {
        case idle, syncing, failure, done
    }

    func handleSync() async {
        do {
            try await handleReadMarkers()
        } catch {
            print("sync error")
            await MainActor.run(body: {
                syncState = .failure
                ToastManager.shared.setError(error: error)
            })
        }
    }

    private func handleAnilistSync() async throws {
        guard let chapters = threadSafeChapters else {
            return
        }

        var id: Int?

        if let idStr = content.trackerInfo?["al"], let x = Int(idStr) {
            id = x
        } else {
            id = getSavedTrackerLink()
        }

        guard let id = id else { return }

        let entry = try await Anilist.shared.getProfile(id).mediaListEntry

        if let entry = entry {
            let progress = entry.progress
            let targets = chapters.filter { $0.number <= Double(progress) }
            DataManager.shared.bulkMarkChapter(chapters: targets.map { $0.toStoredChapter(withSource: source) })

            let chapter = DataManager.shared.getHighestMarked(id: .init(contentId: sttIdentifier().contentId, sourceId: sttIdentifier().sourceId))
            if let chapter = chapter, Double(progress) < chapter.number {
                do {
                    let _ = try await Anilist.shared.updateMediaListEntry(mediaId: id, data: ["progress": chapter.number])
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }

    private func getSavedTrackerLink() -> Int? {
        let realm = try! Realm()
        let str = realm.objects(TrackerLink.self)
            .where { $0._id == sttIdentifier().id }
            .first?
            .trackerInfo?
            .al
        if let str = str {
            return Int(str)
        }

        return nil
    }

    private func handleReadMarkers() async throws {
        // Check if Syncable
        if !source.sourceInfo.canSync { return }
        let user = try? await source.getAuthenticatedUser()

        guard let _ = user else { return }
        guard let chapters = threadSafeChapters else { return }

        // Set State as Syncing
        await MainActor.run(body: {
            withAnimation {
                syncState = .syncing
            }
        })

        // Get Read Chapters on Source
        let readChapterIds = try await source.getReadChapterMarkers(for: entry.id)

        // Init Realm
        // Save New Chapters
        let targets = chapters
            .filter { readChapterIds.contains($0.id) }
            .map { $0.toStoredChapter(withSource: source) }

        // Mark Chapters As Read
        DataManager.shared.bulkMarkChapter(chapters: targets, completed: true)

        // Get Chapters that are out of sync
        let markers = getOutOfSyncMarkers(with: readChapterIds)
        // Sync to Source
        await source.onChaptersCompleted(contentId: entry.id, chapterIds: markers)

        // TODO: Anilist Chapter Sync

        await MainActor.run(body: {
            syncState = .done
        })
    }

    private func getOutOfSyncMarkers(with ids: [String]) -> [String] {
        let realm = try! Realm()

        let markers = realm
            .objects(ChapterMarker.self)
            .where { $0.chapter.sourceId == source.id }
            .where { $0.chapter.contentId == entry.id }
            .where { $0.completed == true }
            .where { $0.chapter.chapterId.in(ids) }
            .toArray()
            .compactMap { $0.chapter?.chapterId }

        return markers
    }
}

extension ProfileView.ViewModel {
    struct ActionState {
        var state: ProgressState
        var chapter: StoredChapter?
        var marker: (progress: Double, date: Date?)?
    }

    enum ProgressState {
        case none, start, resume, bad_path, reRead, upNext, restart

        var description: String {
            switch self {
            case .none:
                return " - "
            case .start:
                return "Start"
            case .resume:
                return "Resume"
            case .bad_path:
                return "Chapter not Found"
            case .reRead:
                return "Re-read"
            case .upNext:
                return "Up Next"
            case .restart:
                return "Restart"
            }
        }
    }
}
