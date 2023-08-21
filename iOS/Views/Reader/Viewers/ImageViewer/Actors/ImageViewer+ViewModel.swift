//
//  ImageViewer+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import SwiftUI

struct CurrentViewerState: Hashable {
    var chapter: ThreadSafeChapter
    var page: Int
    var pageCount: Int
    var hasPreviousChapter: Bool
    var hasNextChapter: Bool
    
    static var placeholder: Self {
        .init(chapter: .init(id: "", sourceId: "", chapterId: "", contentId: "", index: 0, number: 0, volume: 0, title: nil, language: nil, date: .now, webUrl: nil, thumbnail: nil), page: 0, pageCount: 0, hasPreviousChapter: false, hasNextChapter: false)
    }
}

struct PendingViewerState: Hashable {
    var chapter: ThreadSafeChapter
    var pageIndex: Int?
    var pageOffset: Double?
}

@MainActor
final class IVViewModel: ObservableObject {
    /// Keeps track of the  current viewer state
    @Published var viewerState: CurrentViewerState = .placeholder
    
    /// Keeps track of the load state of each chapter
    @Published var loadState: [ThreadSafeChapter: Loadable<Bool>] = [:]
    
    /// Keeps track of the initial presentation state
    @Published var presentationState : Loadable<Bool> = .idle
    
    /// Controls the sheets that appear
    @Published var control: MenuControl = .init()
    @Published var slider: SliderControl = .init()
    
    @Published var readingMode: ReadingMode = .defaultPanelMode
    
    @Published var title: String = ""
    
    @Published var chapterCount = 0
    
    let dataCache = IVDataCache()
    
    var pendingState: PendingViewerState?
}

// MARK: State & Initial Load
extension IVViewModel {
    func consume(_ value: InitialIVState) async {
        title = value.title
        presentationState = .loading
        chapterCount = value.chapters.count
        setReadingMode(for: value.openTo.contentIdentifier.id)
        let requested = value.openTo.toThreadSafe()
        let chapters = value.chapters
        
        // Sort Chapters
        let useIndex = chapters.map { $0.index }.reduce(0, +) > 0
        let sorted =  useIndex ? chapters.sorted(by: { $0.index > $1.index }) : chapters.sorted(by: { $0.number > $1.number })
        
        // Set Chapters
        await dataCache.setChapters(sorted.map { $0.toThreadSafe() })
        
        // Define State
        pendingState = .init(chapter: requested)
        // Load Initial Chapter
        do {
            try await dataCache.load(for: requested)
            updateChapterState(for: requested, state: .loaded(true))
            await MainActor.run {
                withAnimation {
                    presentationState = .loaded(true)
                }
            }
        } catch {
            updateChapterState(for: requested, state: .failed(error))
            Logger.shared.error(error, "Reader")
            await MainActor.run {
                withAnimation {
                    presentationState = .failed(error)
                }
            }
        }
        
    }
    
    @MainActor
    func updateChapterState(for chapter: ThreadSafeChapter, state: Loadable<Bool>) {
        loadState.updateValue(state, forKey: chapter)
    }
    
    @MainActor
    func setViewerState(_ state: CurrentViewerState) {
        viewerState = state
    }
    
    func setReadingMode(for id: String) {
        readingMode = STTHelpers.getReadingMode(for: id)
    }
    
    func producePendingState() {
        pendingState = .init(chapter: viewerState.chapter, pageIndex: viewerState.page - 1, pageOffset:  nil)
    }
    
    @MainActor
    func resetToChapter(_ chapter: ThreadSafeChapter) async {
        presentationState = .loading
        pendingState = .init(chapter: chapter)
        // Load Initial Chapter
        do {
            try await dataCache.load(for: chapter)
            updateChapterState(for: chapter, state: .loaded(true))
            await MainActor.run {
                withAnimation {
                    presentationState = .loaded(true)
                }
            }
        } catch {
            updateChapterState(for: chapter, state: .failed(error))
            Logger.shared.error(error, "Reader")
            await MainActor.run {
                withAnimation {
                    presentationState = .failed(error)
                }
            }
        }
    }
    
    func isCurrentlyReading(_ chapter: ThreadSafeChapter) -> Bool {
        chapter == viewerState.chapter
    }
}

extension IVViewModel {
    @MainActor
    func changeViewerStateChapter(_ chapter: ThreadSafeChapter) {
        if viewerState.chapter.STTContentIdentifier != chapter.STTContentIdentifier {
            setReadingMode(for: chapter.STTContentIdentifier)
        }
        
        viewerState.chapter = chapter
        didChangeViewerStateChapter(with: chapter)
    }
    
    @MainActor
    func updateViewerState(with page: ReaderPage) {
        viewerState.page = page.number
    }
    
    @MainActor
    func updateViewState(with transition: ReaderTransition) {
        guard let count = transition.pageCount else { return }
        viewerState.page = count // Set to last page
    }
    
    func didChangeViewerStateChapter(with chapter: ThreadSafeChapter) {
        Task {
            let hasNext = await dataCache.getChapter(after: chapter) != nil
            let hasPrev = await dataCache.getChapter(before: chapter) != nil
            let pages = await dataCache.cache[chapter.id]?.count ?? 0
            
            await MainActor.run {
                viewerState.hasNextChapter = hasNext
                viewerState.hasPreviousChapter = hasPrev
                viewerState.pageCount = pages
            }
        }
    }
}


extension IVViewModel {
    
    nonisolated func toggleMenu() {
        Task { @MainActor in
            control.menu.toggle()
        }
    }
    
    nonisolated func hideMenu() {
        Task { @MainActor in
            control.menu = false
        }
    }
    
    nonisolated func toggleChapterList() {
        Task { @MainActor in
            control.chapterList.toggle()
        }
    }
    
    nonisolated func toggleSettings() {
        Task { @MainActor in
            control.settings.toggle()
        }
    }
    
    nonisolated func toggleComments() {
        Task { @MainActor in
            control.comments.toggle()
        }
    }
}
