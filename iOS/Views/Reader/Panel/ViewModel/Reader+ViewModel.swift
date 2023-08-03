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
        private var cancellables = Set<AnyCancellable>()
        // Core
        var sections: [[AnyObject]] = []
        var readerChapterList: [ReaderChapter] = []
        @Published var activeChapter: ReaderChapter {
            didSet {
                $activeChapter.sink { _ in
                    Task { @MainActor [weak self] in
                        self?.objectWillChange.send()
                    }
                }
                .store(in: &cancellables)
            }
        }

        var scrollingChapter: ReaderChapter

        var chapterList: [ThreadSafeChapter]
        @Published var contentTitle: String?
        @Published var containerReady = false
        // Settings
        @Published var menuControl: MenuControl = .init()
        @Published var slider: SliderControl = .init()
        @Published var IN_ZOOM_VIEW = false
        @Published var scrubbingPageNumber: Int?
        @Published var showNavOverlay = false
        @Published var autoplayEnabled = false

        var chapterCache: [String: ReaderChapter] = [:]
        var chapterSectionCache: [String: Int] = [:]
        var scrollTask: Task<Void, Never>?

        var content: StoredContent?
        var isInLibrary: Bool = false
        // Combine
        let reloadSectionPublisher = PassthroughSubject<Int, Never>()
        let navigationPublisher = PassthroughSubject<ReaderNavigation.NavigationType, Never>()
        let insertPublisher = PassthroughSubject<Int, Never>()
        let reloadPublisher = PassthroughSubject<Void, Never>()
        let scrubEndPublisher = PassthroughSubject<Void, Never>()
        let verticalTimerPublisher = PassthroughSubject<Void, Never>()

        // Additional Helpers
        init(chapterList: [StoredChapter], openTo chapter: StoredChapter, title: String? = nil, pageIndex: Int? = nil) {
            // Sort Chapter List by either sourceIndex or chapter number
            let sourceIndexAcc = chapterList.map { $0.index }.reduce(0, +)
            let sortedChapters = sourceIndexAcc > 0 ? chapterList.sorted(by: { $0.index > $1.index }) : chapterList.sorted(by: { $0.number > $1.number })
            self.chapterList = sortedChapters.map { $0.toThreadSafe() }

            // Update Content
            let chapter = chapter
            contentTitle = title
            let c: ReaderChapter = .init(chapter: chapter.toThreadSafe())
            activeChapter = c
            scrollingChapter = c
            if let pageIndex = pageIndex {
                activeChapter.requestedPageIndex = pageIndex
            } else {
                activeChapter.requestedPageIndex = -1
            }
            readerChapterList.append(activeChapter)
            setModeToUserSetting()
            updateContentInfo(chapter) // To be safe
        }
        
        func updateContentInfo(_ chapter: StoredChapter) {
            Task {
                let actor = await RealmActor()
                content = await actor.getStoredContent(chapter.sourceId, chapter.contentId)
                if let content {
                    isInLibrary = await actor.isInLibrary(id: content.id)
                }
            }
        }

        func loadChapter(_ chapter: ThreadSafeChapter, asNextChapter: Bool = true) async {
            var alreadyInList = false
            var readerChapter = readerChapterList.first(where: { $0.chapter.id == chapter.id })
            alreadyInList = readerChapter != nil
            if readerChapter == nil {
                readerChapter = ReaderChapter(chapter: chapter)
            }

            guard let readerChapter = readerChapter else {
                return
            }

            chapterCache[chapter.id] = readerChapter
            // Add To Reader Chapters
            if !alreadyInList {
                if asNextChapter {
                    readerChapterList.append(readerChapter)

                } else {
                    readerChapterList.insert(readerChapter, at: 0)
                }
            }

            // Load Chapter Data
            readerChapter.data = .loading
            let cData = await STTHelpers.getChapterData(chapter)
            switch cData {
            case let .loaded(t):
                readerChapter.data = .loaded(t.toReadableChapterData())
            case let .failed(error):
                readerChapter.data = .failed(error)
            default: break
            }

            // Get Images
            guard let pages = readerChapter.pages else {
                return
            }

            let section = buildSection(chapter: chapter, pages: pages)

            // Set Opening Page
            if readerChapterList.count == 1, readerChapter.requestedPageIndex == -1 {
                let values = await STTHelpers.getInitialPanelPosition(for: contentIdentifier.id, chapterId: readerChapter.chapter.chapterId, limit: pages.count)
                readerChapter.requestedPageIndex = values.0
                readerChapter.requestedPageOffset = values.1
            }
            // Add to model section
            if asNextChapter {
                sections.append(section)
                chapterSectionCache[readerChapter.chapter.id] = sections.count - 1
            } else {
                chapterSectionCache.forEach { k, v in chapterSectionCache.updateValue(v + 1, forKey: k) }
                chapterSectionCache[readerChapter.chapter.id] = 0
                sections.insert(section, at: 0)
            }

            if readerChapterList.count == 1 {
                reloadPublisher.send()
            } else {
                insertPublisher.send(asNextChapter ? sections.count - 1 : 0)
            }

            Task { @MainActor in
                containerReady = true
            }
            if pages.isEmpty {
                loadNextChapter()
            }
        }

        func buildSection(chapter: ThreadSafeChapter, pages: [ReaderPage]) -> [AnyObject] {
            guard let chapterIndex = chapterList.firstIndex(where: { $0 == chapter }) else { return [] }
            // Prepare Chapter
            var chapterObjects: [AnyObject] = []

            // Add Previous Transition for first chapter
            if chapterIndex == 0 {
                let preceedingChapter = recursiveGetChapter(for: chapter, isNext: false)
                let prevTransition = ReaderView.Transition(from: chapter, to: preceedingChapter, type: .PREV)
                chapterObjects.append(prevTransition)
            }

            // Add Pages
            chapterObjects.append(contentsOf: pages)

            // Add Transition To Next Page if transitions are enabled OR This is the last chapter
            let nextChapter = recursiveGetChapter(for: chapter)
            if Preferences.standard.forceTransitions || nextChapter == nil {
                let transition = ReaderView.Transition(from: chapter, to: nextChapter, type: .NEXT)
                if nextChapter == nil || chapterObjects.count > 10 { // Add Transition Pages for End or Chapters with 10 or more pages
                    chapterObjects.append(transition)
                }
            }

            return chapterObjects
        }

        func getChapterIndex(_ chapter: ThreadSafeChapter) -> Int? {
            chapterList.firstIndex(of: chapter)
        }

        func reload(section: Int) {
            reloadSectionPublisher.send(section)
        }

        func getObject(atPath path: IndexPath) -> AnyObject {
            sections[path.section][path.item]
        }

        func getChapter(at index: Int) -> ReaderChapter? {
            readerChapterList.get(index: index)
        }

        func loadNextChapter() {
            let currentChapter = Preferences.standard.isReadingVertically ? scrollingChapter : activeChapter
            guard let nextChapter = recursiveGetChapter(for: currentChapter.chapter) else {
                return
            }

            Task {
                await loadChapter(nextChapter)
            }
        }

        func loadPreviousChapter() {
            let currentChapter = Preferences.standard.isReadingVertically ? scrollingChapter : activeChapter
            guard let target = recursiveGetChapter(for: currentChapter.chapter, isNext: false) else {
                return
            }

            Task {
                await loadChapter(target, asNextChapter: false)
            }
        }

        var title: String {
            content?.title ?? contentTitle ?? ""
        }

        @MainActor
        func handleNavigation(_ point: CGPoint) {
            if !UserDefaults.standard.bool(forKey: STTKeys.TapSidesToNavigate) || IN_ZOOM_VIEW {
                Task { @MainActor in
                    menuControl.toggleMenu()
                }
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
    func recursiveGetChapter(for chapter: ThreadSafeChapter, isNext: Bool = true) -> ThreadSafeChapter? {
        let index = getChapterIndex(chapter)
        guard let index else { return nil }
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
        Task { @MainActor in
            slider.min = min
            slider.max = max
        }
    }
}

extension ReaderView.ViewModel {
    var NextChapter: ThreadSafeChapter? {
        guard let current = getChapterIndex(activeChapter.chapter) else { return nil }
        let index = current + 1
        return chapterList.get(index: index)
    }

    var PreviousChapter: ThreadSafeChapter? {
        guard let current = getChapterIndex(activeChapter.chapter) else { return nil }
        let index = current - 1
        return chapterList.get(index: index)
    }
}

extension ReaderView.ViewModel {
    func resetToChapter(_ chapter: ThreadSafeChapter) {
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
        // Get Page
        let item = sections[path.section][path.item]

        guard let readerPage = item as? ReaderPage else {
            if let transition = item as? ReaderView.Transition {
                handleTransition(transition: transition)
            }
            return
        }
        let page = readerPage.page

        // Moved to next chapter
        if page.chapterId != activeChapter.chapter.id, let chapter = chapterCache[page.chapterId] {
            onChapterChanged(chapter: chapter)
            onPageChanged(page: page)
            return
        }

        // Last Page of same chapter
        if page.index + 1 == activeChapter.pages?.count, let chapter = chapterCache[page.chapterId], recursiveGetChapter(for: chapter.chapter) == nil {
            onPageChanged(page: page)
            onChapterChanged(chapter: chapter)
        } else {
            // Reg, Page Change
            onPageChanged(page: page)
        }
    }

    private var incognitoMode: Bool {
        Preferences.standard.incognitoMode
    }

    private var sourcesDisabledFromProgressMarking: [String] {
        .init(rawValue: UserDefaults.standard.string(forKey: STTKeys.SourcesDisabledFromHistory) ?? "") ?? []
    }

    private func canMark(sourceId: String) -> Bool {
        !sourcesDisabledFromProgressMarking.contains(sourceId)
    }

    private func onPageChanged(page: ReaderView.Page) {
        activeChapter.requestedPageIndex = page.index
        if incognitoMode { return } // Incoginito

        // Save Progress
        guard let chapter = chapterCache[page.chapterId], canMark(sourceId: chapter.chapter.sourceId) else {
            return
        }
        
        let id = contentIdentifier.id
        let target = chapter.chapter
        let lastPageRead = chapter.requestedPageIndex + 1
        let pageCount = chapter.pages?.count ?? 1
        let offset = chapter.requestedPageOffset.flatMap(Double.init)
        
        Task {
            let actor = await RealmActor()
            await actor.updateContentProgress(for: id,
                                              chapter: target,
                                              lastPageRead: lastPageRead,
                                              totalPageCount: pageCount,
                                              lastPageOffset: offset)
        }
        guard !STTHelpers.isInternalSource(chapter.chapter.sourceId) else {
            return
        }
        let cl = chapter.chapter
        let idx = page.index + 1
        
        Task {
            guard let source = await DSK.shared.getSource(id: cl.sourceId) else { return }
            do {
                try await source.onPageRead(contentId: cl.contentId, chapterId: cl.chapterId, page: idx)
            } catch {
                Logger.shared.error(error, source.id)
            }
        }
    }

    private func handleTransition(transition: ReaderView.Transition) {
        if transition.to == nil {
            Task { @MainActor in
                menuControl.menu = true
            }
        }
        if incognitoMode { return }

        // Update Progress
        let from = transition.from
        if let chapter = chapterCache[from.id], activeChapter !== chapter, let count = chapter.pages?.count {
            activeChapter = chapter
            activeChapter.requestedPageIndex = count - 1 // Last Page
        }

        // Progress Update
        let chapter = transition.from
        let identifier = contentIdentifier.id
        if transition.to == nil {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                Task {
                    let actor = await RealmActor()
                    await actor.didCompleteChapter(for: identifier, chapter: chapter)
                }
            }
        }

        if let num = transition.to?.number, num > transition.from.number {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                Task {
                    let actor = await RealmActor()
                    await actor.didCompleteChapter(for: identifier, chapter: chapter)
                }
            }
        }
    }

    private func onChapterChanged(chapter: ReaderView.ReaderChapter) {
        let lastChapter = activeChapter
        Task { @MainActor in
            activeChapter = chapter
        }

        if incognitoMode { return }

        // Moving to Previous Chapter, Do Not Mark as Completed
        if lastChapter.chapter.number > chapter.chapter.number {
            return
        }

        if !canMark(sourceId: lastChapter.chapter.sourceId) {
            return
        }

        let id = contentIdentifier.id
        // Mark As Completed & Update Unread Count
        Task {
            let actor = await RealmActor()
            await actor.didCompleteChapter(for: id, chapter: lastChapter.chapter)
            await self.handleSourceSync(contentId: lastChapter.chapter.contentId,
                                        sourceId: lastChapter.chapter.sourceId,
                                        chapterId: lastChapter.chapter.chapterId)
        }
    }

    private func handleSourceSync(contentId: String, sourceId: String, chapterId: String) async {
        guard let source = await DSK.shared.getSource(id: sourceId), source.intents.chapterSyncHandler else { return }
        // Services
        do {
            try await source.onChapterRead(contentId: contentId, chapterId: chapterId)
        } catch {
            Logger.shared.error(error, source.id)
        }
    }
}

// MARK: Reading Mode

extension ReaderView.ViewModel {
    var contentIdentifier: ContentIdentifier {
        ContentIdentifier(contentId: activeChapter.chapter.contentId, sourceId: activeChapter.chapter.sourceId)
    }

    func setModeToUserSetting() {
        let id = contentIdentifier
        let container = UserDefaults.standard
        let key = STTKeys.ReaderType + "%%" + id.id
        let value = container.object(forKey: key)
        let defaultMode = ReadingMode.defaultPanelMode
        guard let value = value as? Int else {
            updateViewerMode(with: defaultMode)
            return
        }
        let mode = ReadingMode(rawValue: value)
        guard let mode else {
            updateViewerMode(with: defaultMode)
            return
        }
        updateViewerMode(with: mode)
    }

    func setReadingModeForContent(_ value: ReadingMode) {
        let id = contentIdentifier
        let container = UserDefaults.standard
        let key = STTKeys.ReaderType + "%%" + id.id
        container.setValue(value.rawValue, forKey: key)
        updateViewerMode(with: value)
    }

    func updateViewerMode(with mode: ReadingMode) {
        let defaults = UserDefaults.standard
        let preferences = Preferences.standard
        switch mode {
        case .PAGED_MANGA:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = false
            preferences.isPagingVertically = false
            defaults.set(ReadingMode.PAGED_MANGA.rawValue, forKey: STTKeys.ReaderType)
        case .PAGED_COMIC:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = true
            preferences.isPagingVertically = false
            defaults.set(ReadingMode.PAGED_COMIC.rawValue, forKey: STTKeys.ReaderType)

        case .VERTICAL:
            preferences.isReadingVertically = true
            preferences.isPagingVertically = false
            preferences.VerticalPagePadding = false
            defaults.set(ReadingMode.VERTICAL.rawValue, forKey: STTKeys.ReaderType)

        case .VERTICAL_SEPARATED:
            preferences.isReadingVertically = true
            preferences.VerticalPagePadding = true
            preferences.isPagingVertically = false
            defaults.set(ReadingMode.VERTICAL_SEPARATED.rawValue, forKey: STTKeys.ReaderType)

        case .PAGED_VERTICAL:
            preferences.isReadingVertically = false
            preferences.isPagingVertically = true
            defaults.set(ReadingMode.PAGED_VERTICAL.rawValue, forKey: STTKeys.ReaderType)

        default: break
        }
    }
}
