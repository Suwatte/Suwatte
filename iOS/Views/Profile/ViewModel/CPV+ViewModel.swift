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
        @Published var entry: DaisukeEngine.Structs.Highlight
        
        var source: AnyContentSource
        var sourceID: String {
            source.id
        }
        var contentID: String {
            entry.contentId
        }
        
        @Published var content: DSKCommon.Content = .placeholder
        @Published var chapters: [ThreadSafeChapter] = []
        
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
        @Published var resolvingLinks = false
        @Published var actionState: ActionState = .init(state: .none)
        @Published var linked: [ContentLinkSection] = []
        // Tokens
        internal var currentMarkerToken: NotificationToken?
        internal var downloadTrackingToken: NotificationToken?
        internal var progressToken: NotificationToken?
        internal var libraryTrackingToken: NotificationToken?
        internal var readLaterToken: NotificationToken?
        
        internal var linkedContentIDs = [String]()
        @Published var downloads: [String: DownloadStatus] = [:]
        @Published var readChapters = Set<Double>()
        @Published var savedForLater: Bool = false
        @Published var inLibrary: Bool = false
        
        init(_ entry: DaisukeEngine.Structs.Highlight, _ source: AnyContentSource) {
            self.entry = entry
            self.source = source
            self.currentChapterSection = source.id
        }
        
        @Published var selection: String?
        // De Init
        deinit {
            disconnect()
            removeNotifier()
            Logger.shared.debug("deallocated", "ProfileViewModel")
            
        }
        
        var identifier: String {
            STTIDPair.id
        }
        
        var STTIDPair : ContentIdentifier {
            .init(contentId: contentID, sourceId: sourceID)
        }
    }
}

fileprivate typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func load() async {
        await RunnerActor.run {
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
                    
                    await animate { [weak self] in
                        self?.chapters = prepared
                        self?.chapterState = .loaded(true)
                    }
                    
                    // Update Action State
                    await setActionState()
                }
            }
            
            // Load Content From Network
            do {
                content = try await getContentFromSource()
                guard let content else { throw DSK.Errors.InvalidJSONObject }
                await animate { [weak self] in
                    self?.content = content
                    self?.contentState = .loaded(true)
                }
                
                await saveContent(content)
                await loadChapters(content.chapters)
                
                
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
        await RunnerActor.run {
            func prepare(chapters: [DSKCommon.Chapter]) async {
                let prepared = chapters
                    .sorted(by: \.index, descending: false)
                    .map { $0.toThreadSafe(sourceID: sourceID, contentID: contentID) }
                await animate { [weak self] in
                    self?.chapters = prepared
                    self?.chapterState = .loaded(true)
                }
                await saveChapters(chapters)
                await didLoadChapters()
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
                    if chapters.isEmpty {
                        await animate { [weak self] in
                            if Task.isCancelled { return }
                            if self?.chapters.isEmpty ?? true {
                                self?.chapterState = .failed(error)
                            }
                        }
                    }
                }
            }
        }
    }
}


extension ViewModel {
    func didLoadChapters() async {
        let actor = await RealmActor()
        let id = STTIDPair
        
        // Resolve Links, Sync & Update Action State
        await resolveLinks()
        await handleSync()
        await setActionState()
        await actor.updateUnreadCount(for: id)
        await actor.clearUpdates(id: id.id)
    }
}

// Reference: https://medium.com/geekculture/swiftui-animation-completion-b6f0d167159e
extension ViewModel {
    func animate(_ execute: @escaping () -> Void) async {
        let task = Task { @MainActor in
            await withCheckedContinuation { continuation in
                withAnimation(.easeInOut(duration: 0.3)) {
                    execute()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.325) {
                    continuation.resume()
                }
            }
        }
        
        await task.value
    }
}
