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
    final class ViewModel: ObservableObject {
        var entry: DaisukeEngine.Structs.Highlight

        var source: AnyContentSource
        var sourceID: String {
            source.id
        }

        var contentID: String {
            entry.id
        }

        @Published var content: DSKCommon.Content = .placeholder

        @Published var contentState: Loadable<Bool> = .idle
        @Published var chapterState: Loadable<Bool> = .idle

        @Published var currentChapterSection: String
        @Published var presentCollectionsSheet = false
        @Published var presentSafariView = false
        @Published var presentMigrationView = false
        @Published var presentManageContentLinks: String? = nil

        @Published var isWorking = false
        @Published var syncState = SyncState.idle
        @Published var actionState: ActionState = .init(state: .none)
        @Published var chapterMap: [String: ChapterStatement] = [:]
        // Tokens
        var currentMarkerToken: NotificationToken?
        var downloadTrackingToken: NotificationToken?
        var progressToken: NotificationToken?
        var libraryTrackingToken: NotificationToken?
        var readLaterToken: NotificationToken?
        var chapterBookmarkToken: NotificationToken?
        var sourceProgressState: DSKCommon.ContentProgressState?

        var linkedContentIDs = [String]()
        @Published var downloads: [String: DownloadStatus] = [:]
        @Published var readChapters: [String: [String: ThreadSafeProgressMarker]] = [:]
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false
        @Published var bookmarkedChapters = Set<String>()

        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: AnyContentSource) {
            self.entry = entry
            self.source = source
            currentChapterSection = ""
            currentChapterSection = identifier
        }

        var contentInfo: SimpleContentInfo {
            .init(runnerID: sourceID, runnerName: source.name, contentName: entry.title, contentIdentifier: STTIDPair, highlight: entry)
        }

        @Published var selection: ThreadSafeChapter?

        deinit {
            removeNotifier()
        }

        var identifier: String {
            STTIDPair.id
        }

        var STTIDPair: ContentIdentifier {
            .init(contentId: contentID, sourceId: sourceID)
        }

        var readingMode: ReadingMode {
            content.contentType == .novel ?
                .NOVEL_PAGED_COMIC :
                content.recommendedPanelMode ?? .defaultPanelMode
        }
    }
}

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func load() async {
        await RunnerActor.run { [contentInfo] in
            await animate { [weak self] in
                self?.isWorking = true
                self?.contentState = .loading
            }
            // Load Content From DB
            var content = await getContentFromDatabase()

            if let content {
                // Set Content
                await animate { [weak self] in
                    self?.content = content
                    self?.contentState = .loaded(true)
                }

                // Load Linked Titles
                await resolveLinks()

                // Set Chapters
                let chapters = await getChaptersFromDatabase()
                if let chapters {
                    let statement = prepareChapterStatement(chapters, content: contentInfo, loadChapters: true, index: 0)
                    await animate { [weak self, identifier] in
                        self?.chapterMap[identifier] = statement
                        self?.chapterState = .loaded(true)
                    }

                    // Update Action State
                    await setActionState()
                }
            }

            // Load Content From Network
            do {
                content = try await getContentFromSource()
                guard var content else {
                    throw DSK.Errors.InvalidJSONObject
                }

                let chapters = content.chapters
                content.chapters = nil
                await animate { [weak self] in
                    self?.content = content
                    self?.contentState = .loaded(true)
                }

                Task { [weak self, content] in
                    await self?.saveContent(content)
                }

                await loadChapters(chapters)

            } catch {
                Logger.shared.error(error, "Content Info")
                await animate { [weak self] in
                    if self?.content == .placeholder {
                        self?.contentState = .failed(error)
                    }
                }
            }

            await animate { [weak self] in
                self?.isWorking = false
            }
        }
    }

    func loadChapters(_ pre: [DSKCommon.Chapter]? = nil) async {
        await RunnerActor.run { [contentInfo, chapterMap] in
            func prepare(chapters: [DSKCommon.Chapter]) async {
                let preparedChapters = getPreparedChapters(chapters: chapters)

                await animate { [weak self] in
                    self?.chapterMap[contentInfo.contentIdentifier.id] = self?.prepareChapterStatement(preparedChapters, content: contentInfo, loadChapters: true, index: 0)
                    self?.chapterState = .loaded(true)
                }
                Task.detached { [weak self] in
                    await self?.saveChapters(chapters)
                }
                Task.detached { [weak self] in
                    await self?.didLoadChapters()
                }
            }

            // Load Chapters From Network
            do {
                var chapters = pre
                if chapters == nil {
                    chapters = try await getChaptersFromSource()
                }

                await prepare(chapters: chapters!)
            } catch {
                Logger.shared.error(error, "Content Chapters")
                let chapters = chapterMap[contentInfo.contentIdentifier.id]?.filtered

                guard chapters == nil || (chapters?.isEmpty ?? true) else { return }
                await animate { [weak self] in
                    if Task.isCancelled { return }
                    self?.chapterState = .failed(error)
                }
            }
        }
    }

    func reload() async {
        removeNotifier()
        await animate { [weak self] in
            self?.chapterState = .loading
            self?.contentState = .loading
            self?.chapterMap = [:]
            self?.linkedContentIDs = []
            self?.actionState = .init(state: .none)
            self?.downloads = [:]
            self?.readChapters = [:]
            self?.savedForLater = false
            self?.inLibrary = false
            self?.bookmarkedChapters = .init()
            self?.currentChapterSection = self?.identifier ?? ""
        }
        await load()
        await setupObservers()
    }
}

extension ViewModel {
    func didLoadChapters() async {
        Task { [STTIDPair] in
            let actor = await RealmActor.shared()
            let id = STTIDPair
            await actor.updateUnreadCount(for: id)
            await actor.clearUpdates(id: id.id)
        }
        // Resolve Links, Sync & Update Action State
        await updateSourceProgressState()
        await setActionState()
        await handleSync()
        await setActionState(false)
    }
}

// Reference: https://medium.com/geekculture/swiftui-animation-completion-b6f0d167159e
func animate(duration: Double = 0.25, _ execute: @escaping () -> Void) async {
    let task = Task { @MainActor in
        await withCheckedContinuation { continuation in
            withAnimation(.easeInOut(duration: duration)) {
                execute()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.050) {
                continuation.resume()
            }
        }
    }

    await task.value
}

extension ViewModel {
    func updateSourceProgressState() async {
        guard source.intents.progressSyncHandler ?? false else { return }
        do {
            guard let user = try await source.getAuthenticatedUser() else { return }
        } catch {
            Logger.shared.error(error, "{getAuthenticatedUser}-\(source.id)")
        }
        do {
            let data = try await source.getProgressState(for: entry.id)
            sourceProgressState = data
        } catch {
            Logger.shared.error(error, "{getProgressState}-\(source.id)")
        }
    }
}
