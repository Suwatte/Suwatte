//
//  Reader+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import Combine
import SwiftUI

extension ReaderView {
    @MainActor
    final class ViewModel: ObservableObject {
        @Published var updater = false

        // Core
        @Published var sections: [[AnyHashable]] = []
        @Published var readerChapterList: [ReaderChapter] = []
        @Published var activeChapter: ReaderChapter
        var chapterList: [StoredChapter]
        @Published var contentTitle: String?

        // Settings
        @Published var menuControl: MenuControl = .init()
        @Published var slider: SliderControl = .init()
        @Published var IN_ZOOM_VIEW = false
        @Published var scrubbingPageNumber: Int?
        @Published var showNavOverlay = false

        var chapterCache: [String: ReaderChapter] = [:]
        var scrollTask: Task<Void, Never>?
        // Combine
        let reloadSectionPublisher = PassthroughSubject<Int, Never>()
        let navigationPublisher = PassthroughSubject<ReaderNavigation.NavigationType, Never>()
        let insertPublisher = PassthroughSubject<Int, Never>()
        let reloadPublisher = PassthroughSubject<Void, Never>()
        let scrubEndPublisher = PassthroughSubject<Void, Never>()
        init(chapterList: [StoredChapter], openTo chapter: StoredChapter, title: String? = nil, pageIndex: Int? = nil, readingMode: ReadingMode) {
            // Sort Chapter List by either sourceIndex or chapter number
            let sourceIndexAcc = chapterList.map { $0.index }.reduce(0, +)
            self.chapterList = sourceIndexAcc > 0 ? chapterList.sorted(by: { $0.index > $1.index }) : chapterList.sorted(by: { $0.number > $1.number })
            if chapter.chapterType == .LOCAL {
                DataManager.shared.storeChapters([chapter])
            }
            contentTitle = title
            activeChapter = .init(chapter: chapter)
            if let pageIndex = pageIndex {
                activeChapter.requestedPageIndex = pageIndex
            } else {
                activeChapter.requestedPageIndex = -1
            }
            readerChapterList.append(activeChapter)
            updateViewerMode(with: readingMode)
        }

        func loadChapter(_ chapter: StoredChapter, asNextChapter: Bool = true) async {
            let alreadyInList = readerChapterList.contains(where: { $0.chapter._id == chapter._id })
            let readerChapter: ReaderChapter?

            readerChapter = alreadyInList ? readerChapterList.first(where: { $0.chapter._id == chapter._id })! : ReaderChapter(chapter: chapter)

            guard let readerChapter = readerChapter else {
                return
            }

            chapterCache[chapter._id] = readerChapter
            // Add To Reader Chapters
            if !alreadyInList {
                if asNextChapter {
                    readerChapterList.append(readerChapter)

                } else {
                    readerChapterList.insert(readerChapter, at: 0)
                }

                notifyOfChange()
            }

            // Load Chapter Data
            readerChapter.data = .loading
            readerChapter.data = await STTHelpers.getChapterData(chapter)
            notifyOfChange()

            // Get Images
            guard let pages = readerChapter.pages else {
                return
            }

            let chapterIndex = chapterList.firstIndex(where: { $0 == chapter })! // Should never fail

            // Prepare Chapter
            var chapterObjects: [AnyHashable] = []

            // Add Previous Transition for first chapter
            if chapterIndex == 0 {
                let preceedingChapter = recursiveGetChapter(for: chapter, isNext: false)
                let prevTransition = ReaderView.Transition(from: chapter, to: preceedingChapter, type: .PREV)
                chapterObjects.append(prevTransition)
            }

            // Add Pages
            chapterObjects.append(contentsOf: pages)

            // Add Transition To Next Page

            let nextChapter = recursiveGetChapter(for: chapter)
            let transition = ReaderView.Transition(from: chapter, to: nextChapter, type: .NEXT)

            chapterObjects.append(transition)

            // Set Opening Page
            if readerChapterList.count == 1, readerChapter.requestedPageIndex == -1 {
                let values = STTHelpers.getInitialPosition(for: readerChapter.chapter, limit: pages.count)
                readerChapter.requestedPageIndex = values.0
                readerChapter.requestedPageOffset = values.1
            }
            // Add to model section
            if asNextChapter {
                sections.append(chapterObjects)
            } else {
                sections.insert(chapterObjects, at: 0)
            }

            if readerChapterList.count == 1 {
                reloadPublisher.send()
            } else {
                insertPublisher.send(asNextChapter ? sections.count - 1 : 0)
            }

//            print("DONE : \(chapter.displayName)\nSection Count: \(sections.count)\n")

            if pages.isEmpty {
                loadNextChapter()
            }
        }

        func getChapterIndex(_ chapter: StoredChapter) -> Int {
            chapterList.firstIndex(where: { $0 == chapter })!
        }

        func reload(section: Int) {
            reloadSectionPublisher.send(section)
        }

        func notifyOfChange() {
            updater.toggle()
        }

        func getObject(atPath path: IndexPath) -> AnyHashable {
            sections[path.section][path.item]
        }

        func loadNextChapter() {
            guard let lastChapter = readerChapterList.last?.chapter, let nextChapter = recursiveGetChapter(for: lastChapter) else {
                return
            }

            Task { @MainActor in
                await loadChapter(nextChapter)
            }
        }

        func loadPreviousChapter() {
            guard let lastChapter = readerChapterList.first?.chapter, let target = recursiveGetChapter(for: lastChapter, isNext: false) else {
                return
            }

            Task { @MainActor in
                await loadChapter(target, asNextChapter: false)
            }
        }

        var content: StoredContent? {
            let chapter = activeChapter.chapter
            return DataManager.shared.getStoredContent(chapter.sourceId, chapter.contentId)
        }

        var title: String {
            content?.title ?? contentTitle ?? ""
        }

        func handleNavigation(_ point: CGPoint) {
            if !UserDefaults.standard.bool(forKey: STTKeys.TapSidesToNavigate) || IN_ZOOM_VIEW {
                menuControl.toggleMenu()
                return
            }
            var navigator: ReaderView.ReaderNavigation.Modes?

            let vertical = Preferences.standard.isReadingVertically
            navigator = .init(rawValue: UserDefaults.standard.integer(forKey: vertical ? STTKeys.VerticalNavigator : STTKeys.PagedNavigator))

            guard let navigator = navigator else {
                return
            }

            var action = navigator.mode.action(for: point, ofSize: UIScreen.main.bounds.size)

            if Preferences.standard.invertTapSidesToNavigate {
                if action == .LEFT { action = .RIGHT }
                else if action == .RIGHT { action = .LEFT }
            }

            switch action {
            case .MENU:
                menuControl.toggleMenu()
            case .LEFT:
                menuControl.hideMenu()
                navigationPublisher.send(action)
            case .RIGHT:
                menuControl.hideMenu()
                navigationPublisher.send(action)
            }
        }
    }
}

extension ReaderView.ViewModel {
    func recursiveGetChapter(for chapter: StoredChapter, isNext: Bool = true) -> StoredChapter? {
        let index = getChapterIndex(chapter)
        let nextChapter = chapterList.get(index: index + (isNext ? 1 : -1))

        guard let nextChapter = nextChapter else {
            return nil
        }

        if nextChapter.volume == chapter.volume, nextChapter.number == chapter.number {
            return recursiveGetChapter(for: nextChapter, isNext: isNext)
        } else {
            return nextChapter
        }
    }
}

extension ReaderView.ViewModel: ReaderSliderManager {
    func updateSliderOffsets(min: CGFloat, max: CGFloat) {
        slider.min = min
        slider.max = max
    }
}

extension ReaderView.ViewModel {
    var NextChapter: StoredChapter? {
        let index = getChapterIndex(activeChapter.chapter) + 1
        return chapterList.get(index: index)
    }

    var PreviousChapter: StoredChapter? {
        let index = getChapterIndex(activeChapter.chapter) - 1
        return chapterList.get(index: index)
    }
}

extension ReaderView.ViewModel {
    func resetToChapter(_ chapter: StoredChapter) {
        activeChapter = .init(chapter: chapter)
        readerChapterList.removeAll()
        sections.removeAll()
        readerChapterList.append(activeChapter)
        Task { @MainActor in
            await self.loadChapter(chapter, asNextChapter: false)
        }
    }
}

extension ReaderView.ViewModel {
    func didScrollTo(path: IndexPath) {
        scrollTask?.cancel()
        scrollTask = nil
        scrollTask = Task {
            // Get Page
            let page = sections[path.section][path.item]

            guard let page = page as? ReaderView.Page else {
                if let transition = page as? ReaderView.Transition {
                    handleTransition(transition: transition)
                }
                return
            }

            if page.chapterId != activeChapter.chapter._id, let chapter = chapterCache[page.chapterId] {
                onChapterChanged(chapter: chapter)
                return
            }

            // Last Page
            if page.index + 1 == activeChapter.pages?.count, let chapter = chapterCache[page.chapterId], recursiveGetChapter(for: chapter.chapter) == nil {
                onChapterChanged(chapter: chapter)
            } else {
                // Reg, Page Change
                onPageChanged(page: page)
            }

            // TODO: Handle Auto Flag Changing
        }
        // Reset CollectionView.
    }

    private var incognitoMode: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.incognito)
    }

    private var sourcesDisabledFromProgressMarking: [String] {
        .init(rawValue: UserDefaults.standard.string(forKey: STTKeys.SourcesDisabledFromHistory) ?? "") ?? []
    }

    private func canMark(sourceId: String) -> Bool {
        !sourcesDisabledFromProgressMarking.contains(sourceId)
    }

    private func onPageChanged(page: ReaderView.Page) {
        activeChapter.requestedPageIndex = page.index
        if incognitoMode || activeChapter.chapter.chapterType == .OPDS { return } // Incoginito or OPDS which does not track progress

        // Save Progress
        if let chapter = chapterCache[page.chapterId], canMark(sourceId: chapter.chapter.sourceId) {
            DataManager.shared.setProgress(from: chapter)
        }

        // Update Entry Last Read
        if let content = content {
            DataManager.shared.updateLastRead(forId: content._id)
        }
    }

    private func handleTransition(transition: ReaderView.Transition) {
        if transition.to == nil {
            menuControl.menu = true
        }
        if incognitoMode || activeChapter.chapter.chapterType == .OPDS { return }

        let chapter = transition.from
        if transition.to == nil {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                DataManager.shared.setProgress(chapter: chapter)
            }
        }

        if let num = transition.to?.number, num > transition.from.number {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                DataManager.shared.setProgress(chapter: chapter)
            }
        }
    }

    private func onChapterChanged(chapter: ReaderView.ReaderChapter) {
        let lastChapter = activeChapter
        activeChapter = chapter

        if incognitoMode || activeChapter.chapter.chapterType == .OPDS { return }

        // Moving to Previous Chapter, Do Not Mark as Completed
        if lastChapter.chapter.number > chapter.chapter.number {
            return
        }

        // Mark As Completed
        if canMark(sourceId: lastChapter.chapter.sourceId) {
            DataManager.shared.setProgress(chapter: lastChapter.chapter)
        }

        // Trackers
        let trackerInfo = getTrackerInfo(DaisukeEngine.Structs.SuwatteContentIdentifier(contentId: lastChapter.chapter.contentId, sourceId: lastChapter.chapter.sourceId).id)
        let chapterNumber = Int(lastChapter.chapter.number)
        var chapterVolume: Int?
        if let vol = lastChapter.chapter.volume {
            chapterVolume = Int(vol)
        }
        Task {
            // Anilist
            do {
                try await STTHelpers.syncToAnilist(mediaID: trackerInfo?.al, progress: chapterNumber, progressVolume: chapterVolume)
            } catch {
                print(error)
            }
        }

        // Services
        let source = DaisukeEngine.shared.getSource(with: lastChapter.chapter.sourceId)
        Task {
            await source?.onChaptersCompleted(contentId: lastChapter.chapter.contentId, chapterIds: [lastChapter.chapter.chapterId])
        }
    }

    private func getTrackerInfo(_ id: String) -> StoredTrackerInfo? {
        return nil
    }
}

// MARK: Tracker

extension STTHelpers {
    static func syncToAnilist(mediaID: String?, progress: Int, progressVolume: Int?) async throws {
        guard let mediaID = mediaID, let mediaID = Int(mediaID), Anilist.signedIn() else {
            return
        }

        // Get Media

        let media = try await Anilist.shared.getProfile(mediaID)

        // Check if Tracking
        guard let mediaListEntry = media.mediaListEntry else {
            return
        }

        // Progress is above current point
        if mediaListEntry.progress > progress {
            return
        }

        let data = ["progress": progress, "progressVolume": progressVolume]

        _ = try await Anilist.shared.updateMediaListEntry(mediaId: mediaID, data: data as Anilist.JSON)
    }
}

// MARK: Reading Mode

extension ReaderView.ViewModel {
    func updateViewerMode(with mode: ReadingMode) {
        let preferences = Preferences.standard
        switch mode {
        case .PAGED_MANGA:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = false
        case .PAGED_COMIC:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = true
        case .VERTICAL:
            preferences.isReadingVertically = true
            preferences.addImagePadding = false
        case .VERTICAL_SEPARATED:
            preferences.isReadingVertically = true
            preferences.addImagePadding = false
        default: break
        }
    }
}
