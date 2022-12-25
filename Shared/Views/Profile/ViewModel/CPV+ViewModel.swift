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

// Reference: KingBri <https://github.com/bdashore3>
extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double = 1.0) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

extension ProfileView {
    final class ViewModel: ObservableObject {
        @Published var entry: DaisukeEngine.Structs.Highlight
        var source: DaisukeContentSource

        @Published var content: DSKCommon.Content = .placeholder
        @Published var loadableContent: Loadable<Bool> = .idle
        var storedContent: StoredContent {
            try! content.toStoredContent(withSource: source.id)
        }

        @Published var chapters: Loadable<[StoredChapter]> = .idle
        @Published var working = false
        @Published var linkedHasUpdate = false

        @Published var presentCollectionsSheet = false
        @Published var presentTrackersSheet = false
        @Published var presentSafariView = false
        @Published var presentBookmarksSheet = false
        @Published var presentAddContentLink = false
        @Published var presentManageContentLinks = false
        @Published var presentMigrationView = false
        @Published var syncState = SyncState.idle
        @Published var lastReadMarker: ChapterMarker?
        @Published var actionState: ActionState = .init(state: .none)
        @Published var linkedUpdates: [HighlightIndentier] = []
        @Published var threadSafeChapters: [DSKCommon.Chapter]?
        var notificationToken: NotificationToken?
        var syncTask: Task<Void, Error>?
        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: DaisukeContentSource) {
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
            Task { @MainActor in
                self.content = parsed
                self.loadableContent = .loaded(true)
                self.working = false
            }
            Task {
                await self.loadChapters(parsed.chapters)
            }
            if let stored = try? parsed.toStoredContent(withSource: source.id) {
                DataManager.shared.storeContent(stored)
            }

        } catch {
            Task {
                await loadChapters()
            }
            await MainActor.run(body: {
                if loadableContent.LOADED {
                    ToastManager.shared.error("Failed to Update Profile")
                    Logger.shared.error("[ProfileView] \(error.localizedDescription)", .init(function: #function))
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
            let unmanaged = chapters.map { $0.toStoredChapter(withSource: source.id) }
            await MainActor.run(body: {
                threadSafeChapters = chapters
                self.chapters = .loaded(unmanaged)
                working = false
            })
            let stored = chapters.map { $0.toStoredChapter(withSource: source.id) }
            DataManager.shared.storeChapters(stored)
            await didLoadChapters()

        } else {
            do {
                let parsedChapters = try await source.getContentChapters(contentId: entry.id)

                let unmanaged = parsedChapters.map { $0.toStoredChapter(withSource: source.id) }
                await MainActor.run(body: {
                    threadSafeChapters = parsedChapters
                    self.chapters = .loaded(unmanaged)
                    working = false
                })
                let stored = parsedChapters.map { $0.toStoredChapter(withSource: source.id) }
                DataManager.shared.storeChapters(stored)
                await didLoadChapters()

            } catch {
                Task { @MainActor in
                    setChaptersFromDB()
                }
                Logger.shared.error(error.localizedDescription)
                await MainActor.run(body: {
                    if chapters.LOADED {
                        ToastManager.shared.error("Failed to Fetch Chapters")
                        return
                    } else {
                        chapters = .failed(error)
                    }
                    working = false
                    ToastManager.shared.error(error)
                })
            }
        }
    }

    func removeNotifier() {
        notificationToken?.invalidate()
        notificationToken = nil
    }

    func didLoadChapters() async {
        Task {
            await getMarkers()
            try await Task.sleep(seconds: 0.5)
            await handleSync()
            try await handleAnilistSync()
        }
        Task {
            DataManager.shared.clearUpdates(id: sttIdentifier().id)
        }
        Task {
            await checkLinkedForUpdates()
        }
    }

    func setChaptersFromDB() {
        let realm = try! Realm()
        let storedChapters = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == entry.contentId }
            .where { $0.sourceId == source.id }
            .sorted(by: \.index, ascending: true)
            .map { $0 } as [StoredChapter]

        if storedChapters.isEmpty { return }

        chapters = .loaded(storedChapters)
        Task {
            await getMarkers()
        }
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
                    ToastManager.shared.error(error)
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

        let target = DataManager.shared.getStoredContent(source.id, entry.id)

        if let target = target {
            do {
                let c = try target.toDSKContent()
                await MainActor.run(body: {
                    content = c
                    loadableContent = .loaded(true)
                })

            } catch {}
        }

        Task {
            await loadContentFromNetwork()
        }
    }

    func sttIdentifier() -> ContentIdentifier {
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
            Logger.shared.error("[ProfileView] [Sync] - \(error.localizedDescription)")
            await MainActor.run(body: {
                syncState = .failure
                ToastManager.shared.error(error)
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
            DataManager.shared.bulkMarkChapter(chapters: targets.map { $0.toStoredChapter(withSource: source.id) })

            let chapter = DataManager.shared.getHighestMarked(id: .init(contentId: sttIdentifier().contentId, sourceId: sttIdentifier().sourceId))
            if let chapter = chapter, Double(progress) < chapter.number {
                do {
                    let _ = try await Anilist.shared.updateMediaListEntry(mediaId: id, data: ["progress": chapter.number])
                } catch {
                    Logger.shared.error("[ProfileView] [Anilist] \(error.localizedDescription)")
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
        guard let source = source as? DSK.LocalContentSource else { return }
        // Check if Syncable
        if !source.canSyncUserLibrary { return }
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
            .filter { readChapterIds.contains($0.chapterId) }
            .map { $0.toStoredChapter(withSource: source.id) }

        // Mark Chapters As Read
        DataManager.shared.bulkMarkChapter(chapters: targets, completed: true)

        // Get Chapters that are out of sync
        let markers = getOutOfSyncMarkers(with: readChapterIds)
        // Sync to Source
        await source.onChaptersMarked(contentId: entry.id, chapterIds: markers, completed: true)

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

// MARK: Linked Content

extension ProfileView.ViewModel {
    func checkLinkedForUpdates() async {
        let linked = DataManager.shared.getLinkedContent(for: sttIdentifier().id)
        let identifiers: [HighlightIndentier] = linked.map(({ ($0.sourceId, $0.toHighlight()) }))
        let lastChapter = threadSafeChapters?.first

        guard let lastChapter, !linked.isEmpty else {
            return
        }

        let updates = await withTaskGroup(of: (Bool, HighlightIndentier).self, returning: [HighlightIndentier].self, body: { group -> [HighlightIndentier] in
            for entry in identifiers {
                guard let src = DaisukeEngine.shared.getSource(with: entry.sourceId) else {
                    continue
                }

                group.addTask {
                    let chapters = try? await src.getContentChapters(contentId: entry.entry.contentId)
                    guard let target = chapters?.first else {
                        return (false, entry)
                    }

                    let hasChapterOfHigherNumber = target.number > lastChapter.number
                    return (hasChapterOfHigherNumber, entry)
                }
            }

            var matches: [HighlightIndentier] = []
            for await result in group {
                if result.0 {
                    matches.append(result.1)
                }
            }
            return matches
        })

        Task { @MainActor in
            self.linkedUpdates = updates
        }
    }
}
