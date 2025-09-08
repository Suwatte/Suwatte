//
//  ImageViewer+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import RealmSwift
import SwiftUI

@MainActor
final class IVViewModel: ObservableObject {
    /// Keeps track of the  current viewer state
    @Published var viewerState: CurrentViewerState = .placeholder

    /// Keeps track of the load state of each chapter
    @Published var loadState: [ThreadSafeChapter: Loadable<Bool>] = [:]

    /// Keeps track of the initial presentation state
    @Published var presentationState: Loadable<Bool> = .idle

    /// Controls the sheets that appear
    @Published var control: MenuControl = .init()
    @Published var slider: SliderControl = .init()

    @Published var readingMode: ReadingMode = .defaultPanelMode
    @Published var scrollbarPosition: ReaderScrollbarPosition = .defaultScrollbarPosition
    @Published var bottomScrollbarDirection: ReaderBottomScrollbarDirection = .defaultBottomScrollbarDirection
    @Published var scrollbarWidth: CGFloat = 14.0

    @Published var title: String = ""

    @Published var chapterCount = 0

    let dataCache = IVDataCache()

    var pendingState: PendingViewerState?
    var isDoublePaged: Bool?
}

// MARK: State & Initial Load

extension IVViewModel {
    func consume(_ value: InitialIVState) async throws {
        title = value.title
        presentationState = .loading
        chapterCount = value.chapters.count
        var requested = value.openTo
        let chapters = value.chapters

        if !chapters.contains(requested) {
            let newTarget = chapters.first(where: { $0.id == requested.id })
            guard let newTarget else {
                presentationState = .failed(DSK.Errors.NamedError(name: "MismatchError", message: "target chapter was not found in chapter list"))
                return
            }
            requested = newTarget
        }

        setReadingMode(for: requested.STTContentIdentifier, requested: value.mode)
        setScrollbar(for: requested.STTContentIdentifier)

        // Sort Chapters
        let useIndex = chapters.map { $0.index }.reduce(0, +) > 0
        let sorted = useIndex ? chapters.sorted(by: { $0.index > $1.index }) :
            chapters.sorted(by: { $0.number > $1.number })

        // Set Chapters
        await dataCache.setChapters(sorted)

        // Define State
        pendingState = .init(chapter: requested,
                             pageIndex: value.pageIndex,
                             pageOffset: value.pageOffset)

        // Load Initial Chapter
        try await dataCache.load(for: requested)
        let pageCount = await dataCache.getCount(requested.id)
        // Check DB For Last Known State
        if pendingState?.pageIndex == nil {

            let values = await STTHelpers.getInitialPanelPosition(for: requested.id, limit: pageCount)
            pendingState?.pageIndex = values.0
            pendingState?.pageOffset = values.1
        }

        updateChapterState(for: requested, state: .loaded(true))
        presentationState = .loaded(true)
    }

    @MainActor
    func updateChapterState(for chapter: ThreadSafeChapter, state: Loadable<Bool>) {
        loadState.updateValue(state, forKey: chapter)
    }

    @MainActor
    func setViewerState(_ state: CurrentViewerState) {
        viewerState = state
    }

    func setReadingMode(for id: String, requested: ReadingMode?) {
        if Preferences.standard.overrideProvidedReaderMode {
            readingMode = Preferences.standard.defaultPanelReadingMode
        } else {
            readingMode = STTHelpers.getReadingMode(for: id) ?? requested ?? .defaultPanelMode
        }

        Preferences.standard.currentReadingMode = readingMode
    }

    func setScrollbar(for id: String) {
        scrollbarPosition = STTHelpers.getScrollbarPosition(for: id) ?? .defaultScrollbarPosition
        bottomScrollbarDirection = STTHelpers.getBottomScrollbarDirection(for: id) ?? .defaultBottomScrollbarDirection
        scrollbarWidth = Preferences.standard.readerScrollbarWidth
    }

    func setIsDoublePaged(isDoublePaged: Bool) {
        self.isDoublePaged = isDoublePaged
    }

    func producePendingState() {
        pendingState = .init(chapter: viewerState.chapter,
                             pageIndex: viewerState.page - 1,
                             pageOffset: nil)
    }

    @MainActor
    func resetToChapter(_ chapter: ThreadSafeChapter) async {
        pendingState = .init(chapter: chapter)
        presentationState = .loading
        loadState = [:]
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
    func updateViewerStateChapter(_ chapter: ThreadSafeChapter) {
        viewerState.chapter = chapter
        didChangeViewerStateChapter(with: chapter)
    }

    @MainActor
    func updateViewerState(with page: ReaderPage) {
        viewerState.page = page.number
    }

    @MainActor
    func updateViewerState(with transition: ReaderTransition) {
        guard let count = transition.pageCount else { return }
        viewerState.page = count // Set to last page
    }

    func didChangeViewerStateChapter(with chapter: ThreadSafeChapter) {
        Task {
            let hasNext = await dataCache.getChapter(after: chapter) != nil
            let hasPrev = await dataCache.getChapter(before: chapter) != nil
            let pages = await dataCache.getCount(chapter.id)

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
            withAnimation(.easeInOut(duration: 0.25)) {
                control.menu.toggle()
            }
        }
    }

    nonisolated func hideMenu() {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.25)) {
                control.menu = false
            }
        }
    }

    nonisolated func showMenu() {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.25)) {
                control.menu = true
            }
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

extension IVViewModel {
    func isChapterBookmarked(id: String) -> Bool {
        let realm = try! Realm()

        let target = realm
            .objects(ChapterBookmark.self)
            .where { $0.id == id && !$0.isDeleted }
            .first

        return target != nil
    }
}
