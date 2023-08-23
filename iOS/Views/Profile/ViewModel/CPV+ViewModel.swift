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

// MARK: - Definition

extension ProfileView {
    final class ViewModel: ObservableObject {
        @Published var entry: DaisukeEngine.Structs.Highlight
        var source: AnyContentSource

        @Published var content: DSKCommon.Content = .placeholder
        @Published var loadableContent: Loadable<Bool> = .idle
        var storedContent: StoredContent {
            try! content.toStoredContent(withSource: source.id)
        }

        @Published var chapters: Loadable<[StoredChapter]> = .idle
        @Published var working = false
        @Published var presentCollectionsSheet = false
        @Published var presentTrackersSheet = false
        @Published var presentSafariView = false
        @Published var presentBookmarksSheet = false
        @Published var presentManageContentLinks = false {
            didSet {
                if !presentManageContentLinks { // Dismissed check if linked changed, if so refresh
                    Task {
                        let actor = await RealmActor()
                        let newLinked = await actor.getLinkedContent(for: contentIdentifier).map(\.id)
                        if newLinked != linkedContentIDs {
                            await MainActor.run {
                                self.loadableContent = .idle
                                self.chapters = .idle
                            }
                        }
                    }
                }
            }
        }

        @Published var presentMigrationView = false
        @Published var syncState = SyncState.idle
        @Published var resolvingLinks = false
        @Published var actionState: ActionState = .init(state: .none)
        @Published var threadSafeChapters: [DSKCommon.Chapter]?
        // Tokens
        var currentMarkerToken: NotificationToken?
        private var linkedContentIDs = [String]()

        // Download Tracking Variables
        var downloadTrackingToken: NotificationToken?
        @Published var downloads: [String: DownloadStatus] = [:]
        // Chapter Marking Variables
        var progressToken: NotificationToken?
        @Published var readChapters = Set<Double>()

        // Library Tracking Token
        var libraryTrackingToken: NotificationToken?
        var readLaterToken: NotificationToken?

        // Library State Values
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false

        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: AnyContentSource) {
            self.entry = entry
            self.source = source
        }

        @Published var selection: String?
        // De Init
        deinit {
            disconnect()
            removeNotifier()
        }

        var contentIdentifier: String {
            sttIdentifier().id
        }

        func sttIdentifier() -> ContentIdentifier {
            .init(contentId: entry.id, sourceId: source.id)
        }
    }
}

// MARK: - Observers

extension ProfileView.ViewModel {
    func disconnect() {
        currentMarkerToken?.invalidate()
        progressToken?.invalidate()
        downloadTrackingToken?.invalidate()
        libraryTrackingToken?.invalidate()
        readLaterToken?.invalidate()
    }

    func setupObservers() async {
        let actor = await RealmActor()
        
        // Observe Progress Markers
        let id = contentIdentifier
        progressToken = await actor
            .observeReadChapters(for: id) { [weak self] value in
                self?.readChapters = value
                Task { [weak self] in
                    await self?.setActionState()
                }
            }
        
        // Observe Library
        libraryTrackingToken = await actor
            .observeLibraryState(for: id) { [weak self] value in
                self?.inLibrary = value
            }

        // Observe Saved For Later
        readLaterToken = await actor
            .observeReadLaterState(for: id) { [weak self] value in
                self?.savedForLater = value
            }

        // Observe Downloads
        downloadTrackingToken = await actor
            .observeDownloadStatus(for: id) { [weak self] value in
                self?.downloads = value
            }
                
    }
    
    func removeNotifier() {
        currentMarkerToken?.invalidate()
        currentMarkerToken = nil

        progressToken?.invalidate()
        progressToken = nil

        downloadTrackingToken?.invalidate()
        downloadTrackingToken = nil

        libraryTrackingToken?.invalidate()
        libraryTrackingToken = nil

        readLaterToken?.invalidate()
        readLaterToken = nil
    }
}

// MARK: - Content Loading

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
            
            guard !Task.isCancelled else { return }

            await loadChapters(parsed.chapters)
            

            // Save to Realm
            let actor = await RealmActor()
            let stored = try parsed.toStoredContent(withSource: source.id)
            await actor.storeContent(stored)
        } catch {
            guard !Task.isCancelled else { return }
            await loadChapters()

            
            Task { @MainActor [weak self] in
                if self?.loadableContent.LOADED ?? false {
                    ToastManager.shared.error("Failed to Update Profile")
                    Logger.shared.error("[ProfileView] \(error.localizedDescription)")
                } else {
                    self?.loadableContent = .failed(error)
                }
                self?.working = false
            }
        }
    }

    func loadContentFromDatabase() async {
        let actor = await RealmActor()
        
        Task { @MainActor in
            withAnimation {
                loadableContent = .loading
            }
        }

        let target = await actor.getStoredContent(source.id, entry.id)

        if let target = target {
            do {
                let c = try target.toDSKContent()
                Task { @MainActor in
                    withAnimation {
                        content = c
                        loadableContent = .loaded(true)
                    }
                }
            } catch {}
        }

        if StateManager.shared.NetworkStateHigh || target == nil { // Connected To Network OR The Content is not saved thus has to be fetched regardless
            await loadContentFromNetwork()
        } else {
            await loadChaptersfromDB()
        }
    }
}

// MARK: - Chapter Loading

extension ProfileView.ViewModel {
    func loadChapters(_ parsedChapters: [DSKCommon.Chapter]? = nil) async {
        Task { @MainActor in
            withAnimation {
                working = true
                threadSafeChapters = parsedChapters
            }
        }
        
        let sourceId = source.id
        do {
            // Fetch Chapters
            var chapters = parsedChapters
            if chapters == nil {
                chapters = try await source.getContentChapters(contentId: entry.id)
            }
            guard let chapters else { fatalError("Chapters Should be defined") }

            // Prepare Unmanaged Chapters
            let unmanaged = chapters.map { $0.toStoredChapter(withSource: source.id) }.sorted(by: \.index, descending: false)

            // Update UI with fetched values
            Task { @MainActor in
                withAnimation {
                    threadSafeChapters = chapters
                    self.chapters = .loaded(unmanaged)
                    working = false
                }
            }
            // Store To Realm
            Task {
                let actor = await RealmActor()
                let stored = chapters.map { $0.toStoredChapter(withSource: sourceId) }
                await actor.storeChapters(stored)
            }

            // Post Chapter Load Actions
            Task {
                await didLoadChapters()
            }

        } catch {
            Logger.shared.error(error, source.id)
            await loadChaptersfromDB()

            Task { @MainActor in
                if chapters.LOADED  {
                    ToastManager.shared.error("Failed to Fetch Chapters: \(error.localizedDescription)")
                    return
                } else {
                    chapters = .failed(error)
                }
                working = false
            }
        }
    }

    func loadChaptersfromDB() async {
        let actor = await RealmActor()
        
        let storedChapters = await actor.getChapters(source.id, content: entry.contentId)
        if storedChapters.isEmpty { return }
        Task { @MainActor in
            chapters = .loaded(storedChapters)
        }
        await setActionState()
    }

    func didLoadChapters() async {
        let actor = await RealmActor()
        let id = sttIdentifier()

        // Resolve Links, Sync & Update Action State
        await resolveLinks()
        await handleSync()
        await setActionState()
        await actor.updateUnreadCount(for: id)
        await actor.clearUpdates(id: id.id)
    }
}

// MARK: - Linking

extension ProfileView.ViewModel {
    // Handles the addition on linked chapters
    func resolveLinks() async {
        Task { @MainActor in
            working = true
        }
        defer {
            Task { @MainActor in
                working = false
            }
        }
        guard let threadSafeChapters else { return }

        let actor = await RealmActor()
        // Contents that this title is linked to
        let entries = await actor
            .getLinkedContent(for: contentIdentifier)

        linkedContentIDs = entries
            .map(\.id)

        // Ensure there are linked titles
        guard !entries.isEmpty, !Task.isCancelled else { return }

        // Get The current highest chapter on the viewing source
        let currentMaxChapter = threadSafeChapters.map(\.number).max() ?? 0.0

        // Get Distinct Chapters which are higher than our currnent max available
        let chaptersToBeAdded = await withTaskGroup(of: [(String, DSKCommon.Chapter)].self, body: { group in
            // Build
            for entry in entries {

                // Get Chapters from source that are higher than our current max available chapter
                group.addTask {
                    guard let source = await DSK.shared.getSource(id: entry.sourceId) else { return [] }

                    do {
                        let chapters = try await source.getContentChapters(contentId: entry.contentId)
                        // Save to db
                        Task {
                            let actor = await RealmActor()
                            let stored = chapters.map { $0.toStoredChapter(withSource: source.id) }
                            await actor.storeChapters(stored)
                        }
                        return chapters
                            .filter { $0.number > currentMaxChapter }
                            .map { (source.id, $0) }

                    } catch {
                        Logger.shared.error(error, source.id)
                    }
                    return []
                }
            }

            // Resolve
            var out: [(String, DSKCommon.Chapter)] = []

            for await result in group {
                guard !result.isEmpty else { continue } // empty guard
                out.append(contentsOf: result)
            }

            return out
                .distinct(by: \.1.number)
                .sorted(by: \.1.number, descending: true)
        })

        // Get the highest index point, remember the higher the index, the more recent the chapter

        // Prepare Unmanaged Chapters
        let base = (chapters.value ?? []).sorted(by: \.index, descending: false)
        let newChapters = chaptersToBeAdded.map { $0.1.toStoredChapter(withSource: $0.0) }
        // Correct Indexes
        let unmanaged = (newChapters + base)
            .enumerated()
            .map { idx, c in
                c.index = idx
                return c
            }
        let prepped = threadSafeChapters + chaptersToBeAdded.map(\.1)
        // Update UI with fetched values
        await MainActor.run { [weak self] in
            withAnimation {
                self?.threadSafeChapters = prepped
                self?.chapters = .loaded(unmanaged)
            }
        }
    }
}

// MARK: - Sync

extension ProfileView.ViewModel {
    enum SyncState: Hashable {
        case idle, syncing, done
    }

    func handleSync() async {
        await MainActor.run {
            self.syncState = .syncing
        }
        await syncWithAllParties()
        await MainActor.run {
            self.syncState = .done
        }
    }

    // Sync

    func syncWithAllParties() async {
        let actor = await RealmActor()
        let identifier = sttIdentifier()
        let chapterNumbers = Set(threadSafeChapters?.map(\.number) ?? [])
        // gets tracker matches in a [TrackerID:EntryID] format
        let matches: [String: String] = await actor.getTrackerLinks(for: contentIdentifier)

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
                        let item = try await tracker.getTrackItem(id: value)
                        let originMaxReadChapter = item.entry?.progress.lastReadChapter ?? 0
                        return (tracker.id, originMaxReadChapter)
                    } catch {
                        Logger.shared.error(error, tracker.id)
                        return (tracker.id, 0)
                    }
                }
            }

            var markers: [String: Double] = [:]

            for await(key, chapter) in group {
                markers[key] = chapter
            }
            return markers
        })

        // Source Chapter Sync Handler
        var sourceOriginHighestRead: Double = 0
        if source.intents.chapterSyncHandler {
            do {
                let chapterIds = try await source.getReadChapterMarkers(contentId: entry.contentId)
                sourceOriginHighestRead = threadSafeChapters?
                    .filter { chapterIds.contains($0.chapterId) }
                    .map(\.number)
                    .max() ?? 0
            } catch {
                Logger.shared.error(error, source.id)
            }
        }

        // Prepare the Highest Read Chapter Number
        let localHighestRead = await actor.getHighestMarkedChapter(id: identifier.id)
        let originHighestRead = Array(markers.values).max() ?? 0
        let maxRead = max(localHighestRead, originHighestRead, sourceOriginHighestRead)

        // Max Read is 0, do not sync
        guard maxRead != 0 else { return }

        // Update Origin Value if outdated
        await withTaskGroup(of: String?.self, body: { group in
            for (key, value) in markers {
                guard let tracker = await DSK.shared.getTracker(id: key), maxRead > value, let entryId = matches[key] else { return }
                group.addTask {
                    do {
                        try await tracker.didUpdateLastReadChapter(id: entryId, progress: .init(chapter: maxRead, volume: nil))
                        return tracker.id
                    } catch {
                        Logger.shared.error(error, tracker.id)
                    }
                    return nil
                }
            }

            for await result in group {
                guard let result else { continue }
                Logger.shared.debug("Sync Complete", result)
            }
        })

        // Update Local Value if outdated, sources are notified if they have the Chapter Event Handler
        guard maxRead != localHighestRead else { return }
        let chaptersToMark = chapterNumbers.filter { $0 <= maxRead }
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

// MARK: - Action State

extension ProfileView.ViewModel {
    struct ActionState: Hashable {
        var state: ProgressState
        var chapter: ChapterInfo?
        var marker: Marker?

        struct ChapterInfo: Hashable {
            var name: String
            var id: String
        }

        struct Marker: Hashable {
            var progress: Double
            var date: Date?
        }
    }

    enum ProgressState: Int, Hashable {
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

    func setActionState() async {
        let state = await calculateActionState()
        Task { @MainActor in
            withAnimation {
                self.actionState = state
            }
        }
    }

    func calculateActionState() async -> ActionState {
        guard let chapters = chapters.value, !chapters.isEmpty else {
            return .init(state: .none)
        }

        guard content.contentId == entry.contentId else {
            return .init(state: .none)
        }
        
        let actor = await RealmActor()
        
        let marker = await actor
            .getLatestLinkedMarker(for: contentIdentifier)

        guard let marker else {
            // No Progress marker present, return first chapter
            let chapter = chapters.last!
            return .init(state: .start, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
        }

        guard let chapterRef = marker.currentChapter else {
            // Marker Exists but there is not reference to the chapter
            let maxRead = marker.maxReadChapter

            // Check the max read chapter and use this instead
            guard let maxRead else {
                // No Maximum Read Chapter, meaning marker exists without any reference or read chapers, point to first chapter instead
                let chapter = chapters.last!
                return .init(state: .start, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
            }

            // Get The latest chapter
            guard let targetIndex = chapters.lastIndex(where: { $0.number >= maxRead }) else {
                let target = chapters.first!

                return .init(state: .reRead, chapter: .init(name: target.chapterName, id: target.id))
            }
            // We currently have the index of the last read chapter, if this index points to the last chapter, represent a reread else get the next up
            guard let currentMaxReadChapter = chapters.get(index: targetIndex) else {
                return .init(state: .none) // Should Never Happen
            }

            if currentMaxReadChapter == chapters.first { // Max Read is lastest available chapter
                return .init(state: .reRead, chapter: .init(name: currentMaxReadChapter.chapterName, id: currentMaxReadChapter.id))
            } else if let nextUpChapter = chapters.get(index: max(0, targetIndex - 1)) { // Point to next after max read
                return .init(state: .upNext, chapter: .init(name: nextUpChapter.chapterName, id: nextUpChapter.id))
            }

            return .init(state: .none)
        }

        // Fix Situation where the chapter being referenced is not in the joined chapter list by picking the last where the numbers match
        var correctedChapterId = chapterRef.id
        if !chapters.contains(where: { $0.id == chapterRef.id }), let chapter = chapters.last(where: { $0.number >= chapterRef.number }) {
            correctedChapterId = chapter.id
        }

        //
        let info = ActionState.ChapterInfo(name: chapterRef.chapterName, id: correctedChapterId)

        if !marker.isCompleted {
            // Marker Exists, Chapter has not been completed, resume
            return .init(state: .resume, chapter: info, marker: .init(progress: marker.progress ?? 0.0, date: marker.dateRead))
        }
        // Chapter has been completed, Get Current Index
        guard var index = chapters.firstIndex(where: { $0.id == info.id }) else {
            return .init(state: .none) // Should never occur due to earlier correction
        }

        // Current Index is equal to that of the last available chapter
        // Set action state to re-read
        // marker is nil to avoid progress display
        if index == 0 {
            if content.status == .COMPLETED, let chapter = chapters.last {
                return .init(state: .restart, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
            }
            return .init(state: .reRead, chapter: info, marker: nil)
        }

        // index not 0, decrement, sourceIndex moves inverted
        index -= 1
        let next = chapters.get(index: index)
        return .init(state: .upNext, chapter: next.flatMap { .init(name: $0.chapterName, id: $0.id) }, marker: nil)
    }
}
