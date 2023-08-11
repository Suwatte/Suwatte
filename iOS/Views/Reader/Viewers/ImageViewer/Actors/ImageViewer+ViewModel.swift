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
    var chapter: ThreadSafeChapter?
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
        setReadingMode()
        let requested = value.openTo.toThreadSafe()
        let chapters = value.chapters
        
        // Sort Chapters
        let useIndex = chapters.map { $0.index }.reduce(0, +) > 0
        let sorted =  useIndex ? chapters.sorted(by: { $0.index > $1.index }) : chapters.sorted(by: { $0.number > $1.number })
        
        // Set Chapters
        await dataCache.setChapters(sorted.map { $0.toThreadSafe() })
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
    func incrementViewerStatePage() {
        viewerState.page += 1
    }
    
    @MainActor
    func changeViewerStateChapter(_ chapter: ThreadSafeChapter) {
        viewerState.chapter = chapter
    }
    @MainActor
    func setViewerState(_ state: CurrentViewerState) {
        viewerState = state
    }
    
    func setReadingMode() {
        let preferences = Preferences.standard
        
        preferences.currentReadingMode = .PAGED_COMIC
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
