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
        var source: AnyContentSource
        
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
        @Published var actionState: ActionState = .init(state: .none)
        @Published var linkedUpdates: [HighlightIndentier] = []
        @Published var threadSafeChapters: [DSKCommon.Chapter]?
        // Tokens
        var currentMarkerToken: NotificationToken?
        
        // Download Tracking Variables
        var downloadTrackingToken: NotificationToken?
        @Published var downloads: [String: ICDMDownloadObject] = [:]
        // Chapter Marking Variables
        var progressToken: NotificationToken?
        @Published var readChapters = Set<Double>()
        
        // Library Tracking Token
        var libraryTrackingToken: NotificationToken?
        var readLaterToken: NotificationToken?
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false
        
        // ReadLater Tracking Token
        var syncTask: Task<Void, Error>?
        
        // Anilist ID
        lazy var anilistId: Int? = STTHelpers.getAnilistID(id: sttIdentifier().id)
        
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
        
        func disconnect() {
            currentMarkerToken?.invalidate()
            progressToken?.invalidate()
            downloadTrackingToken?.invalidate()
            libraryTrackingToken?.invalidate()
            readLaterToken?.invalidate()
        }
    }
}

extension ProfileView.ViewModel {
    func setupObservers() {
        let realm = try! Realm()
        
        // Get Read Chapters
        let _r1 = realm
            .objects(ProgressMarker.self)
            .where { $0.id == contentIdentifier && $0.isDeleted == false }
        
        progressToken = _r1.observe { [weak self] _ in
            let target = _r1.first
            guard let target else {
                self?.calculateActionState(nil)
                return
            }
            self?.readChapters = Set(target.readChapters)
            self?.calculateActionState(target.freeze())
        }
        
        // Get Download
        let _r2 = realm
            .objects(ICDMDownloadObject.self)
            .where { $0.chapter.contentId == entry.contentId }
            .where { $0.chapter.sourceId == source.id }
        
        downloadTrackingToken = _r2.observe { [weak self] _ in
            self?.downloads = Dictionary(uniqueKeysWithValues: _r2.map { ($0._id, $0) })
        }
        
        // Get Library
        let id = sttIdentifier().id
        
        let _r3 = realm
            .objects(LibraryEntry.self)
            .where { $0.id == id }
        
        libraryTrackingToken = _r3.observe { [weak self] _ in
            self?.inLibrary = !_r3.isEmpty
        }
        
        // Read Later
        let _r4 = realm
            .objects(ReadLater.self)
            .where { $0.id == id }
            .where { $0.isDeleted == false }
        
        readLaterToken = _r4.observe { [weak self] _ in
            self?.savedForLater = !_r4.isEmpty
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

extension ProfileView.ViewModel {
    func loadContentFromNetwork() async {
        do {
            // Fetch From JS
            let parsed = try await source.getContent(id: entry.id)
            await MainActor.run { [weak self] in
                self?.content = parsed
                self?.loadableContent = .loaded(true)
                self?.working = false
            }
            try Task.checkCancellation()
            try await Task.sleep(seconds: 0.1)
            
            // Load Chapters
            Task.detached { [weak self] in
                await self?.loadChapters(parsed.chapters)
            }
            
            // Save to Realm
            Task.detached { [weak self] in
                if let source = self?.source, let stored = try? parsed.toStoredContent(withSource: source.id) {
                    DataManager.shared.storeContent(stored)
                }
            }
        } catch {
            Task.detached { [weak self] in
                await self?.loadChapters()
            }
            
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
    
    func loadChapters(_ parsedChapters: [DSKCommon.Chapter]? = nil) async {
        await MainActor.run { [weak self] in
            self?.working = true
            self?.threadSafeChapters = parsedChapters
        }
        let sourceId = source.id
        if let chapters = parsedChapters {
            let unmanaged = chapters.map { $0.toStoredChapter(withSource: source.id) }
            await MainActor.run { [weak self] in
                self?.threadSafeChapters = chapters
                self?.chapters = .loaded(unmanaged)
                self?.working = false
            }
            // Store To Realm
            Task.detached {
                let stored = chapters.map { $0.toStoredChapter(withSource: sourceId) }
                DataManager.shared.storeChapters(stored)
            }
            // Post Chapter Load Actions
            Task.detached { [weak self] in
                await self?.didLoadChapters()
            }
        } else {
            do {
                let parsedChapters = try await source.getContentChapters(contentId: entry.id)
                let unmanaged = parsedChapters.map { $0.toStoredChapter(withSource: source.id) }
                await MainActor.run { [weak self] in
                    self?.threadSafeChapters = parsedChapters
                    self?.chapters = .loaded(unmanaged)
                    self?.working = false
                }
                // Store To Realm
                Task.detached {
                    let stored = parsedChapters.map { $0.toStoredChapter(withSource: sourceId) }
                    DataManager.shared.storeChapters(stored)
                }
                // Post Chapter Load Actions
                Task.detached { [weak self] in
                    await self?.didLoadChapters()
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.setChaptersFromDB()
                }
                Logger.shared.error(error.localizedDescription)
                ToastManager.shared.error(error)
                Task { @MainActor [weak self] in
                    if self?.chapters.LOADED ?? false {
                        ToastManager.shared.error("Failed to Fetch Chapters")
                        return
                    } else {
                        self?.chapters = .failed(error)
                    }
                    self?.working = false
                }
            }
        }
    }
    
    var contentIdentifier: String {
        sttIdentifier().id
    }
    
    func didLoadChapters() async {
        let id = sttIdentifier()
        
        Task.detached {
            let obj = DataManager
                .shared
                .getContentMarker(for: id.id)?
                .freeze()
            
            Task { @MainActor [weak self] in
                self?.calculateActionState(obj)
            }
        }
        Task.detached { [weak self] in
            await self?.handleSync()
            try? await self?.handleAnilistSync()
            DataManager.shared.updateUnreadCount(for: id)
        }
        Task.detached {
            DataManager.shared.clearUpdates(id: id.id)
        }
        Task.detached { [weak self] in
            await self?.checkLinkedForUpdates()
        }
    }
    
    func setChaptersFromDB() {
        let realm = try! Realm()
        let storedChapters = realm
            .objects(StoredChapter.self)
            .where { $0.contentId == entry.contentId }
            .where { $0.sourceId == source.id }
            .sorted(by: \.index, ascending: true)
            .map { $0.freeze() } as [StoredChapter]
        if storedChapters.isEmpty { return }
        
        Task { @MainActor in
            chapters = .loaded(storedChapters)
        }
        
        let id = sttIdentifier()
        
        Task.detached {
            let obj = DataManager
                .shared
                .getContentMarker(for: id.id)?
                .freeze()
            
            Task { @MainActor [weak self] in
                self?.calculateActionState(obj)
            }
        }
    }
    
    func calculateActionState(_ marker: ProgressMarker?) {
        guard let chapters = chapters.value else {
            actionState = .init(state: .none)
            return
        }
        
        guard content.contentId == entry.contentId else {
            return
        }
        
        guard let marker, let chapterRef = marker.currentChapter else {
            // Marker DNE, user has not started reading
            
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
                return
            }
            actionState = .init(state: .none)
            return
        }
        
        let info = ActionState.ChapterInfo(name: chapterRef.chapterName, id: chapterRef.id)
        
        if !marker.isCompleted {
            //            // Marker Exists, Chapter has not been completed, resume
            actionState = .init(state: .resume, chapter: info, marker: .init(progress: marker.progress ?? 0.0, date: marker.dateRead))
            return
        }
        // Chapter has been completed, Get Current Index
        guard var index = chapters.firstIndex(where: { $0.chapterId == chapterRef.chapterId }) else {
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
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
                actionState = .init(state: .restart, chapter: .init(name: chapter.chapterName, id: chapter.id), marker: nil)
                return
            }
            actionState = .init(state: .reRead, chapter: info, marker: nil)
            return
        }
        
        // index not 0, decrement, sourceIndex moves inverted
        index -= 1
        let next = chapters.get(index: index)
        actionState = .init(state: .upNext, chapter: next.flatMap { .init(name: $0.chapterName, id: $0.id) }, marker: nil)
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
        
        if StateManager.shared.NetworkStateHigh || target == nil { // Connected To Network OR The Content is not saved thus has to be fetched regardless
            Task {
                await loadContentFromNetwork()
            }
        } else {
            setChaptersFromDB()
        }
    }
    
    func sttIdentifier() -> ContentIdentifier {
        .init(contentId: entry.id, sourceId: source.id)
    }
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
    
    func handleAnilistSync() async throws {
        guard let chapters = threadSafeChapters else {
            return
        }
        
        var id: Int?
        
        if let idStr = content.trackerInfo?["al"], let x = Int(idStr) {
            id = x
        } else {
            id = STTHelpers.getAnilistID(id: sttIdentifier().id)
        }
        
        guard let id = id else { return }
        
        let entry = try await Anilist.shared.getProfile(id).mediaListEntry
        
        guard let entry else { return }
        let progress = entry.progress
        let targets = chapters.filter { $0.number <= Double(progress) }.map(\.number)
        
        DataManager.shared.markChaptersByNumber(for: sttIdentifier(), chapters: Set(targets))
        let highestMarkedChapter = DataManager.shared.getContentMarker(for: contentIdentifier)?.maxReadChapter
        
        guard let highestMarkedChapter, Double(progress) < highestMarkedChapter else {
            return
        }
        
        do {
            let _ = try await Anilist.shared.updateMediaListEntry(mediaId: id, data: ["progress": highestMarkedChapter])
        } catch {
            Logger.shared.error("[ProfileView] [Anilist] \(error.localizedDescription)")
        }
    }
    
    private func handleReadMarkers() async throws {
        // Check if Syncable
        guard source.intents.chapterSyncHandler else {
            return
        }
        let user = try? await source.getAuthenticatedUser()
        
        guard let _ = user else { return }
        guard let chapters = threadSafeChapters else { return }
        
        // Set State as Syncing
        await MainActor.run(body: {
            withAnimation {
                syncState = .syncing
            }
        })
        
        defer {
            Task {
                await MainActor.run(body: {
                    syncState = .done
                })
            }
        }
        
        // Get Read Chapters on Source
        let readChapterIds = try Set(await source.getReadChapterMarkers(contentId: entry.id))
        
        // Get Chapter Numbers of Read Chapters
        let targets = chapters
            .filter { readChapterIds.contains($0.chapterId) }
            .map(\.number)
        
        // Mark Chapters As Read
        DataManager.shared.markChaptersByNumber(for: sttIdentifier(), chapters: Set(targets))
        
        guard source.intents.chapterEventHandler else {
            return
        }
        // Get Chapters that are out of sync
        let markers = getOutOfSyncMarkers(with: Array(readChapterIds))
        // Sync to Source
        try? await source.onChaptersMarked(contentId: entry.id, chapterIds: markers, completed: true)
        
    }
    
    // Gets ID's of chapters that are completed but have not been syned to the source.
    private func getOutOfSyncMarkers(with _: [String]) -> [String] {
        guard let threadSafeChapters else {
            return []
        }
        let marker = DataManager.shared.getContentMarker(for: contentIdentifier)?.readChapters
        
        guard let marker else {
            return []
        }
        let marked = Set(marker)
        
        let results = threadSafeChapters.filter { !marked.contains($0.number) }.map(\.chapterId)
        
        return results
    }
}

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
                guard let src = SourceManager.shared.getSource(id: entry.sourceId) else {
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
