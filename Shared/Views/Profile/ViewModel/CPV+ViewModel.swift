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

        // TODO: Make Chapters Realm Based?
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
        var chapterMarkersToken: NotificationToken?
        @Published var readChapters = Set<Double>()
        
        // Library Tracking Token
        var libraryTrackingToken: NotificationToken?
        var readLaterToken: NotificationToken?
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false
        
        // ReadLater Tracking Token
        var syncTask: Task<Void, Error>?
        
        // Anilist ID
        lazy var anilistId : Int? = {
            STTHelpers.getAnilistID(id: sttIdentifier().id)
        }()
        
        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: DaisukeContentSource) {
            self.entry = entry
            self.source = source
            setupObservers()
        }

        @Published var selection: String?
        // De Init
        deinit {
            currentMarkerToken?.invalidate()
            chapterMarkersToken?.invalidate()
            downloadTrackingToken?.invalidate()
            libraryTrackingToken?.invalidate()
            readLaterToken?.invalidate()
            Logger.shared.debug("CPVM Deallocated")
        }
    }
}
extension ProfileView.ViewModel {
    
    func setupObservers() {
        let realm = try! Realm()
        
        // Get Read Chapters
        let _r1 = realm
            .objects(ChapterMarker.self)
            .where({ $0.chapter.contentId == entry.contentId })
            .where({ $0.chapter.sourceId == source.id })
            .where({ $0.completed == true })
        chapterMarkersToken = _r1.observe({ [weak self] collection in
            switch collection {
                case .initial(let values):
                    let initial = values.map({ $0.chapter!.number })
                    self?.readChapters.formUnion(initial)
                case let .update(_, deleted, inserted, _):
                    let insertedNumbers = inserted.map({ _r1[$0].chapter!.number })
                    let deletedNumbers = deleted.map({ _r1[$0].chapter!.number })
                    self?.readChapters.formUnion(insertedNumbers)
                    self?.readChapters.subtract(deletedNumbers)
                default:
                    break
            }
        })
        
        // Get Download
        let _r2 = realm
            .objects(ICDMDownloadObject.self)
            .where({ $0.chapter.contentId == entry.contentId })
            .where({ $0.chapter.sourceId == source.id })
        
        downloadTrackingToken = _r2.observe({ [weak self] collection in
            self?.downloads =  Dictionary(uniqueKeysWithValues: _r2.map{ ($0._id, $0) })
        })
        
        // Get Library
        let id = sttIdentifier().id
        
        let _r3 = realm
            .objects(LibraryEntry.self)
            .where({ $0._id ==  id})
        
        libraryTrackingToken = _r3.observe({[weak self] _ in
            self?.inLibrary = !_r3.isEmpty
        })
        
        
        // Read Later
        let _r4 = realm
            .objects(ReadLater.self)
            .where({ $0._id ==  id})

        readLaterToken = _r4.observe({[weak self] _ in
            self?.savedForLater = !_r4.isEmpty
        })
    }
    
    func removeNotifier() {
        currentMarkerToken?.invalidate()
        currentMarkerToken = nil
        
        chapterMarkersToken?.invalidate()
        chapterMarkersToken = nil
        
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
                    Logger.shared.error("[ProfileView] \(error.localizedDescription)", .init(function: #function))
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
        
        if let chapters = parsedChapters {
            let unmanaged = chapters.map { $0.toStoredChapter(withSource: source.id) }
            await MainActor.run { [weak self] in
                self?.threadSafeChapters = chapters
                self?.chapters = .loaded(unmanaged)
                self?.working = false
            }
            // Store To Realm
            let sourceId = source.id
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
                let sourceId = source.id
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
        await MainActor.run { [weak self] in
            self?.getMarkers()
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
            .map { $0 } as [StoredChapter]

        if storedChapters.isEmpty { return }

        chapters = .loaded(storedChapters)
        Task { @MainActor in 
            getMarkers()
        }
    }

    
    func getMarkers() {
        let id = entry.id
        let sourceId = source.id
        let realm = try! Realm()
        currentMarkerToken = realm
            .objects(ChapterMarker.self)
            .where { $0.chapter.contentId == id }
            .where { $0.chapter.sourceId == sourceId }
            .where { $0.dateRead != nil }
            .sorted(by: \.dateRead, ascending: false)
            .observe { [weak self] collection in
                switch collection {
                case let .initial(results):
                        self?.calculateActionState(results.first)
                case let .update(results, _, _, _):
                        self?.calculateActionState(results.first)
                case let .error(error):
                    ToastManager.shared.error(error)
                }
            }
        
    }

    func calculateActionState(_ marker: ChapterMarker?) {
        guard let chapters = chapters.value else {
            actionState = .init(state: .none)
            return
        }
        guard content.contentId == entry.contentId else {
            return
        }
        guard let marker, let chapter = marker.chapter?.toThreadSafe() else {
            // Marker DNE, user has not started reading
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: chapter.toThreadSafe(), marker: nil)
                return
            }
            actionState = .init(state: .none)
            return
        }

        if !marker.completed {
            // Marker Exists, series has not been complted, resume
            actionState = .init(state: .resume, chapter: marker.chapter?.toThreadSafe(), marker: (marker.progress, marker.dateRead))
            return
        }

        // Series has been completed

        // Get current chapter index
        guard var index = chapters.firstIndex(where: { $0.chapterId == chapter.chapterId }) else {
            if let chapter = chapters.last {
                // Chapter not found in chapter list, return first chapter
                actionState = .init(state: .start, chapter: chapter.toThreadSafe(), marker: nil)
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
                actionState = .init(state: .restart, chapter: chapter.toThreadSafe(), marker: nil)
                return
            }
            actionState = .init(state: .reRead, chapter: marker.chapter?.toThreadSafe(), marker: nil)
            return
        }

        // index not 0, decrement, sourceIndex moves inverted
        index -= 1
        actionState = .init(state: .upNext, chapter: chapters.get(index: index)?.toThreadSafe(), marker: nil)
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

    func handleAnilistSync() async throws {
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
        var chapter: ThreadSafeChapter?
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

// Reference: https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
class BackgroundWorker: NSObject {
  private var thread: Thread!
  private var block: (()->Void)!

    @objc internal func runBlock() { block() }

  internal func start(_ block: @escaping () -> Void) {
    self.block = block

    let threadName = String(describing: self)
      .components(separatedBy: .punctuationCharacters)[1]

    thread = Thread { [weak self] in
      while (self != nil && !self!.thread.isCancelled) {
        RunLoop.current.run(
            mode: RunLoop.Mode.default,
          before: Date.distantFuture)
      }
      Thread.exit()
    }
    thread.name = "\(threadName)-\(UUID().uuidString)"
    thread.start()

    perform(#selector(runBlock),
      on: thread,
      with: nil,
      waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue])
  }

  public func stop() {
    thread.cancel()
  }
}
