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
    let libraryUpdateRunnerPageLinks = PassthroughSubject<Void, Never>()
    let browseUpdateRunnerPageLinks = PassthroughSubject<Void, Never>()

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
    private var collectionInitialized: Bool = false

    func isCollectionInitialized() -> Bool {
        collectionInitialized
    }

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
            let window = getKeyWindow()
            window?.rootViewController?.present(controller, animated: true)
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
    func openReader(context: DSKCommon.ReaderContext, caller _: DSKCommon.Highlight, source: String) async {
        // Ensure the chapter to be opened is in the provided chapter list
        let targetInList = context.chapters.map(\.chapterId).contains(context.target)
        guard targetInList else {
            alert(title: "Error", message: "Tried opening to a chapter not provided in the chapter list")
            return
        }

        // Save Content, if not saved
        let highlight = context.content
        let streamable = highlight.canStream

        let actor = await RealmActor.shared()
        let id = ContentIdentifier(contentId: highlight.id, sourceId: source).id
        let isSaved = await actor.isContentSaved(id)

        // Target Title is already in the db, Just update the streamble flag
        if isSaved {
            await actor.updateStreamable(id: id, streamable)
        } else {
            // target title not saved to db, save
            let content = highlight.toStored(sourceId: source)
            await actor.storeContent(content)
        }

        // Add Chapters to DB
        let chapters = context
            .chapters
            .map { $0.toThreadSafe(sourceID: source, contentID: highlight.id) }

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
                let context = try await source.provideReaderContext(for: item.id)
                await MainActor.run {
                    ToastManager.shared.loading = false
                }
                await StateManager.shared.openReader(context: context, caller: item, source: sourceId)
            } catch {
                await MainActor.run {
                    StateManager.shared.alert(title: "Error",
                                              message: "\(error.localizedDescription)")
                }
                Logger.shared.error(error, sourceId)
            }
            await MainActor.run {
                ToastManager.shared.loading = false
            }
        }
    }

    func didScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            stopObservingRealm()
//            if blurDuringSwitch() {
//                Task { @MainActor in
//                    removeSplashScreen()
//                }
//            }

        case .inactive:
            if blurDuringSwitch() {
                Task { @MainActor in
                    showSplashScreen()
                }
            }

        case .active:
            if blurDuringSwitch() {
                Task { @MainActor in
                    removeSplashScreen()
                }
            }

            if thumbnailToken == nil, collectionToken == nil {
                Task { @MainActor in
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

        collectionToken = await actor.observeLibraryCollection { value in
            Task { @MainActor in
                withAnimation { [weak self] in
                    self?.collections = value
                    self?.collectionInitialized = true
                }
            }
        }
    }

    func stopObservingRealm() {
        thumbnailToken?.invalidate()
        thumbnailToken = nil

        collectionToken?.invalidate()
        collectionToken = nil
        collectionInitialized = false
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

extension StateManager {
    @MainActor
    func showSplashScreen() {
        let launchScreen = UIStoryboard(name: "STTLaunchScreen", bundle: nil).instantiateInitialViewController()
        guard let launchScreen = launchScreen,
              let launchView = launchScreen.view
        else {
            return
        }

        let window = getKeyWindow()
        guard let window else { return }

        if window.viewWithTag(8888) != nil { return }

        launchView.tag = 8888
        launchView.frame = window.bounds
        window.addSubview(launchView)
        window.makeKeyAndVisible()
    }

    @MainActor
    func removeSplashScreen() {
        guard let window = getKeyWindow(),
              let view = window.viewWithTag(8888)
        else {
            return
        }
        UIView.animate(withDuration: 0.33,
                       delay: 0.0,
                       options: [.curveEaseInOut, .transitionCrossDissolve, .allowUserInteraction])
        {
            view.alpha = 0
        } completion: { _ in
            view.removeFromSuperview()
        }
    }

    func blurDuringSwitch() -> Bool {
        UserDefaults.standard.bool(forKey: STTKeys.BlurWhenAppSwiching)
    }
}
