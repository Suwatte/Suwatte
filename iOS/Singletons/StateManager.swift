//
//  StateManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-12.
//

import Combine
import Foundation
import Network
import Nuke
import RealmSwift
import SwiftUI
import UIKit

final class StateManager: ObservableObject {
    static let shared = StateManager()
    var networkState = NetworkState.unknown
    let monitor = NWPathMonitor()
    let runnerListPublisher = PassthroughSubject<Void, Never>()
    let readerOpenedPublisher = PassthroughSubject<Void, Never>()
    let readerClosedPublisher = PassthroughSubject<Void, Never>()
    @Published var readerState: ReaderState?
    @Published var titleHasCustomThumbs: Set<String> = []
    @Published var collections: [LibraryCollection] = []

    /// This is incremented when a grid related setting is changes
    @Published var gridLayoutDidChange = 0

    // Tokens
    private var thumbnailToken: NotificationToken?
    private var collectionToken: NotificationToken?
    

    func initialize() {
        registerNetworkObserver()
    }

    func registerNetworkObserver() {
        let queue = DispatchQueue.global(qos: .background)
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.networkState = .online
            } else {
                self?.networkState = .offline
            }
        }
    }

    var NetworkStateHigh: Bool {
        networkState == .online || networkState == .unknown
    }

    func clearMemoryCache() {
        ImagePipeline.shared.configuration.imageCache?.removeAll()
    }

    func alert(title: String, message: String) {
        Task { @MainActor in
            let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            controller.addAction(action)
            KEY_WINDOW?.rootViewController?.present(controller, animated: true)
        }
    }
}

extension StateManager {
    enum NetworkState {
        case unknown, online, offline
    }
}

// MARK: - Global Chapter Reading

extension StateManager {
    func openReader(context: DSKCommon.ReaderContext, caller: DSKCommon.Highlight, source: String) async {
        // Ensure the chapter to be opened is in the provided chapter list
        let targetInList = context.chapters.map(\.chapterId).contains(context.target)
        guard targetInList else {
            alert(title: "Error", message: "Tried opening to a chapter not provided in the chapter list")
            return
        }

        // Save Content, if not saved
        let highlight = context.content ?? caller
        let streamable = highlight.canStream

        let actor = await RealmActor.shared()

        let target = await actor.getStoredContent(ContentIdentifier(contentId: highlight.contentId, sourceId: source).id)?.freeze()

        // Target Title is already in the db, Just update the streamble flag
        if let target, target.streamable != streamable {
            await actor.updateStreamable(id: target.id, streamable)
        } else {
            // target title not saved to db, save
            let content = highlight.toStored(sourceId: source)
            await actor.storeContent(content)
        }

        // Add Chapters to DB
        let chapters = context
            .chapters
            .map { $0.toThreadSafe(sourceID: source, contentID: caller.contentId) }

        // Open Reader
        let chapter = chapters.first(where: { $0.chapterId == context.target })!
        Task { @MainActor in
            readerState = .init(title: highlight.title,
                                chapter: chapter,
                                chapters: chapters,
                                requestedPage: context.requestedPage,
                                requestedOffset: nil,
                                readingMode: context.readingMode,
                                dismissAction: nil)
        }
    }

    @MainActor
    func openReader(state: ReaderState) {
        // Ensure the chapter to be opened is in the provided chapter list
        let targetInList = state.chapters.contains(state.chapter)
        guard targetInList else {
            alert(title: "Error", message: "Tried opening to a chapter not provided in the chapter list")
            return
        }

        readerState = state
    }

    func stream(item: DSKCommon.Highlight, sourceId: String) {
        ToastManager.shared.loading = true
        Task {
            do {
                let source = try await DSK.shared.getContentSource(id: sourceId)
                let context = try await source.provideReaderContext(for: item.contentId)
                Task {
                    await MainActor.run {
                        ToastManager.shared.loading = false
                    }
                    await StateManager.shared.openReader(context: context, caller: item, source: sourceId)
                }
            } catch {
                Task { @MainActor in
                    ToastManager.shared.loading = false
                    StateManager.shared.alert(title: "Error",
                                              message: "\(error.localizedDescription)")
                }
                Logger.shared.error(error, sourceId)
            }
        }
    }

    func didScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            stopObservingRealm()
        case .inactive:
            break
        case .active:
            if thumbnailToken == nil && collectionToken == nil {
                Task {
                    await observe()
                }
            }

            break
        @unknown default:
            break
        }
    }
}

// MARK: Custom Thumbs

extension StateManager {
    func observe() async {
        let actor = await RealmActor.shared()

        thumbnailToken = await actor.observeCustomThumbnails { value in
            Task { @MainActor [weak self] in
                self?.titleHasCustomThumbs = value
            }
        }
        
        collectionToken = await actor.observeLibraryCollection({ value in
            Task { @MainActor [weak self] in
                self?.collections = value
            }
        })
    }

    func stopObservingRealm() {
        thumbnailToken?.invalidate()
        thumbnailToken = nil
        
        collectionToken?.invalidate()
        collectionToken = nil
    }
}

// MARK: ReaderState

struct ReaderState: Identifiable {
    var id: String { chapter.id }
    let title: String
    let chapter: ThreadSafeChapter
    let chapters: [ThreadSafeChapter]
    let requestedPage: Int?
    let requestedOffset: Double?
    let readingMode: ReadingMode?
    let dismissAction: (() -> Void)?
}

// TODO: Continue From History
extension StateManager {}

// MARK: Continue From Bookmark

extension StateManager {
    func open(bookmark: UpdatedBookmark) {
        let toaster = ToastManager.shared
        typealias errors = DSK.Errors
        toaster.block {
            let reference = bookmark.chapter
            guard let reference, reference.isValid else {
                throw errors.NamedError(name: "StateManager", message: "invalid reference")
            }

            let actor = await RealmActor.shared()
            // Content
            if let content = reference.content {
                let chapters = await actor.getChapters(content.sourceId,
                                                       content: content.contentId)
                    .map { $0.toThreadSafe() }
                guard let target = chapters.first(where: { $0.id == reference.id }) else {
                    throw errors.NamedError(name: "StateManager", message: "chapter not found")
                }

                let state: ReaderState = .init(title: content.title,
                                               chapter: target,
                                               chapters: chapters,
                                               requestedPage: bookmark.page - 1, // Bookmark uses page rather than index
                                               requestedOffset: bookmark.pageOffsetPCT,
                                               readingMode: content.recommendedPanelMode,
                                               dismissAction: nil)
                await MainActor.run { [weak self] in
                    self?.openReader(state: state)
                }

            } else if let content = reference.opds {
                let chapter = content
                    .toReadableChapter()
                let state: ReaderState = .init(title: content.contentTitle,
                                               chapter: chapter,
                                               chapters: [chapter],
                                               requestedPage: bookmark.page - 1,
                                               requestedOffset: bookmark.pageOffsetPCT,
                                               readingMode: nil,
                                               dismissAction: nil)
                await MainActor.run { [weak self] in
                    self?.openReader(state: state)
                }
            } else if let content = reference.archive {
                let file = try content
                    .getURL()?
                    .convertToSTTFile()
                let chapter = file?.toReadableChapter()
                guard let file, let chapter else {
                    throw errors.NamedError(name: "StateManager", message: "failed to convert to readable chapter")
                }

                let state: ReaderState = .init(title: file.cName,
                                               chapter: chapter,
                                               chapters: [chapter],
                                               requestedPage: bookmark.page - 1,
                                               requestedOffset: bookmark.pageOffsetPCT,
                                               readingMode: nil,
                                               dismissAction: nil)
                await MainActor.run { [weak self] in
                    self?.openReader(state: state)
                }
            }
        }
    }
}
