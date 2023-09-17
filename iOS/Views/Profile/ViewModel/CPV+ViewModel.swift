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

struct SimpleRunnerInfo : Hashable {
    let runnerID: String
    let runnerName: String
}
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
        @Published var presentTrackersSheet = false
        @Published var presentSafariView = false
        @Published var presentMigrationView = false
        @Published var presentManageContentLinks: String? = nil {
            didSet {
                guard presentManageContentLinks == nil else { return }
                Task { [weak self] in
                    await self?.updateContentLinks()
                }
            }
        }

        @Published var isWorking = false
        @Published var syncState = SyncState.idle
        @Published var actionState: ActionState = .init(state: .none)
        @Published var chapterMap : [String: ChapterStatement] = [:]
        // Tokens
        internal var currentMarkerToken: NotificationToken?
        internal var downloadTrackingToken: NotificationToken?
        internal var progressToken: NotificationToken?
        internal var libraryTrackingToken: NotificationToken?
        internal var readLaterToken: NotificationToken?
        internal var chapterBookmarkToken: NotificationToken?
        internal var sourceProgressState: DSKCommon.ContentProgressState?

        internal var linkedContentIDs = [String]()
        @Published var downloads: [String: DownloadStatus] = [:]
        @Published var readChapters = Set<Double>()
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false
        @Published var bookmarkedChapters = Set<String>()

        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: AnyContentSource) {
            self.entry = entry
            self.source = source
            currentChapterSection = source.id
        }
        
        var sourceInfo: SimpleRunnerInfo {
            .init(runnerID: source.id, runnerName: source.name)
        }

        @Published var selection: ThreadSafeChapter?

        deinit {
            removeNotifier()
            Logger.shared.debug("deallocated", "ProfileViewModel")
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
        await RunnerActor.run { [sourceInfo, sourceID] in
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

                // Set Chapters
                let chapters = await getChaptersFromDatabase()
                if let chapters {
                    let prepared = chapters.map { $0.toThreadSafe() }
                    let statement = prepareChapterStatement(prepared, source: sourceInfo)
                    await animate { [weak self] in
                        self?.chapterMap[sourceID] = statement
                        self?.chapterState = .loaded(true)
                    }

                    // Update Action State
                    await setActionState()
                }
            }

            // Load Content From Network
            do {
                content = try await getContentFromSource()
                guard var content else { throw DSK.Errors.InvalidJSONObject }
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
        await RunnerActor.run { [sourceID, sourceInfo] in
            func prepare(chapters: [DSKCommon.Chapter]) async {
                let prepared = chapters
                    .sorted(by: \.index, descending: false)
                    .map { $0.toThreadSafe(sourceID: sourceID, contentID: contentID) }
                await animate { [weak self] in
                    self?.chapterMap[sourceID] = self?.prepareChapterStatement(prepared, source: sourceInfo)
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
            if let chapters = pre {
                await prepare(chapters: chapters)
            } else {
                do {
                    let chapters = try await getChaptersFromSource()
                    await prepare(chapters: chapters)
                } catch {
                    Logger.shared.error(error, "Content Chapters")
                    let chapters = chapterMap[sourceID]?.filtered
                    
                    guard chapters == nil || (chapters?.isEmpty ?? true) else { return }
                    await animate { [weak self] in
                        if Task.isCancelled { return }
                        self?.chapterState = .failed(error)
                    }
                }
            }
        }
    }

    func reload() async {
        await animate { [weak self] in
            self?.chapterState = .loading
            self?.contentState = .loading
        }

        await load()
    }
}

extension ViewModel {
    func didLoadChapters() async {
        // Resolve Links, Sync & Update Action State
        await updateSourceProgressState()
        await setActionState()
        await handleSync()
        await setActionState(false)
        //        await resolveLinks()

        let actor = await RealmActor.shared()
        let id = STTIDPair
        await actor.updateUnreadCount(for: id)
        await actor.clearUpdates(id: id.id)
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
            let data = try await source.getProgressState(for: entry.id)
            sourceProgressState = data
        } catch {
            Logger.shared.error(error, "(getProgressState)-\(source.id)")
        }
    }
}
