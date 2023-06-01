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
        init(chapterList: [StoredChapter], openTo chapter: StoredChapter, title: String? = nil, pageIndex: Int? = nil, readingMode: ReadingMode) {
            // Sort Chapter List by either sourceIndex or chapter number
            let sourceIndexAcc = chapterList.map { $0.index }.reduce(0, +)
            let sortedChapters = sourceIndexAcc > 0 ? chapterList.sorted(by: { $0.index > $1.index }) : chapterList.sorted(by: { $0.number > $1.number })
            self.chapterList = sortedChapters.map { $0.toThreadSafe() }
            
            // Update Content
            let chapter = chapter
            self.content = DataManager.shared.getStoredContent(chapter.sourceId, chapter.contentId)
            if let content  {
                self.isInLibrary = DataManager.shared.isInLibrary(content: content)
            }
            
            contentTitle = title
            activeChapter = .init(chapter: chapter.toThreadSafe())
            if let pageIndex = pageIndex {
                activeChapter.requestedPageIndex = pageIndex
            } else {
                activeChapter.requestedPageIndex = -1
            }
            readerChapterList.append(activeChapter)
            updateViewerMode(with: readingMode)
        }

        func loadChapter(_ chapter: ThreadSafeChapter, asNextChapter: Bool = true) async {
            let alreadyInList = readerChapterList.contains(where: { $0.chapter.id == chapter.id })
            let readerChapter: ReaderChapter?

            readerChapter = alreadyInList ? readerChapterList.first(where: { $0.chapter.id == chapter.id })! : ReaderChapter(chapter: chapter)

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

                notifyOfChange()
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
            notifyOfChange()

            // Get Images
            guard let pages = readerChapter.pages else {
                return
            }

            let section = buildSection(chapter: chapter, pages: pages)

            // Set Opening Page
            if readerChapterList.count == 1, readerChapter.requestedPageIndex == -1 {
                let values = STTHelpers.getInitialPanelPosition(for: contentIdentifier.id, chapterId: readerChapter.chapter.chapterId, limit: pages.count)
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
            let chapterIndex = chapterList.firstIndex(where: { $0 == chapter })! // Should never fail

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
                chapterObjects.append(transition)
            }

            return chapterObjects
        }

        func getChapterIndex(_ chapter: ThreadSafeChapter) -> Int {
            chapterList.firstIndex(of: chapter)!
        }

        func reload(section: Int) {
            reloadSectionPublisher.send(section)
        }

        func notifyOfChange() {
            Task { @MainActor in
                updater.toggle()
            }
        }

        func getObject(atPath path: IndexPath) -> AnyObject {
            sections[path.section][path.item]
        }

        func loadNextChapter() {
            guard let lastChapter = readerChapterList.last?.chapter, let nextChapter = recursiveGetChapter(for: lastChapter) else {
                return
            }

            Task {
                await loadChapter(nextChapter)
            }
        }

        func loadPreviousChapter() {
            guard let lastChapter = readerChapterList.first?.chapter, let target = recursiveGetChapter(for: lastChapter, isNext: false) else {
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
        let index = getChapterIndex(activeChapter.chapter) + 1
        return chapterList.get(index: index)
    }

    var PreviousChapter: ThreadSafeChapter? {
        let index = getChapterIndex(activeChapter.chapter) - 1
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
        if page.chapterId != activeChapter.chapter.id, let chapter = chapterCache[page.chapterId] {
            onChapterChanged(chapter: chapter)
            return
        }

        // Last Page
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
        DataManager.shared.updateContentProgress(for: contentIdentifier.id, chapter: chapter.chapter, lastPageRead: page.number, totalPageCount: chapter.pages?.count ?? 1)
    }

    private func handleTransition(transition: ReaderView.Transition) {
        if transition.to == nil {
            Task { @MainActor in
                menuControl.menu = true
            }
        }
        if incognitoMode { return }

        let chapter = transition.from
        if transition.to == nil {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                DataManager.shared.didCompleteChapter(for: contentIdentifier.id, chapter: chapter)
            }
        }

        if let num = transition.to?.number, num > transition.from.number {
            // Mark As Completed
            if canMark(sourceId: chapter.sourceId) {
                DataManager.shared.didCompleteChapter(for: contentIdentifier.id, chapter: chapter)
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
        Task.detached { [weak self] in
            // Mark As Completed & Update Unread Count
            
            DataManager.shared.didCompleteChapter(for: id, chapter: lastChapter.chapter)

            // Anilist Sync
            await self?.handleTrackerSync(number: lastChapter.chapter.number,
                              volume: lastChapter.chapter.volume)

            // Source Sync
            await self?.handleSourceSync(contentId: lastChapter.chapter.contentId,
                             sourceId: lastChapter.chapter.sourceId,
                             chapterId: lastChapter.chapter.chapterId)
        }
    }

    private func getStoredTrackerInfo() -> StoredTrackerInfo? {
        let id = ContentIdentifier(contentId: activeChapter.chapter.contentId, sourceId: activeChapter.chapter.sourceId).id
        return DataManager.shared.getTrackerInfo(id)
    }

    private func getLinkedTrackerInfo() -> [String: String?]? {
        let identifier = ContentIdentifier(contentId: activeChapter.chapter.contentId, sourceId: activeChapter.chapter.sourceId)
        return try? DataManager.shared.getPossibleTrackerInfo(for: identifier.id)
    }

    private func handleTrackerSync(number: Double, volume: Double?) {
        let chapterNumber = Int(number)
        let chapterVolume = volume.map { Int($0) }

        // Ids
        let id = ContentIdentifier(contentId: activeChapter.chapter.contentId, sourceId: activeChapter.chapter.sourceId).id
        // Anilist
        Task {
            let alId = STTHelpers.getAnilistID(id: id).flatMap({ String($0) })
            do {
                try await STTHelpers.syncToAnilist(mediaID: alId, progress: chapterNumber, progressVolume: chapterVolume)
            } catch {
                ToastManager.shared.error("Anilist Sync Failed")
            }
        }
    }

    private func handleSourceSync(contentId: String, sourceId: String, chapterId: String) {
        // Services
        let source = SourceManager.shared.getSource(id: sourceId) as? any SyncableSource
        Task {
            do {
                try await source?.onChapterRead(contentId: contentId, chapterId: chapterId)

            } catch {
                ToastManager.shared.info("Failed to Sync Read Marker")
            }
        }
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

        var entry = media.mediaListEntry

        if entry == nil, Preferences.standard.nonSelectiveSync {
            entry = try await Anilist.shared.beginTracking(id: mediaID)
        }

        guard let mediaListEntry = entry else {
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
    var contentIdentifier: ContentIdentifier {
        ContentIdentifier(contentId: activeChapter.chapter.contentId, sourceId: activeChapter.chapter.sourceId)
    }

    func setModeToUserSetting() -> Bool {
        let id = contentIdentifier
        let container = UserDefaults.standard
        let key = STTKeys.ReaderType + "%%" + id.id
        let value = container.object(forKey: key)
        guard let value = value as? Int else {
            return false
        }
        let mode = PanelReadingModes(rawValue:value)
        guard let mode else {
            return false
        }
        updateViewerMode(with: mode)
        return true
    }
    
    func updateViewerMode(with mode: PanelReadingModes) {
        let preferences = Preferences.standard

        switch mode {
        case .PAGED_MANGA:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = false
            preferences.isPagingVertically = false
        case .PAGED_COMIC:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = true
            preferences.isPagingVertically = false

        case .VERTICAL:
            preferences.isReadingVertically = true
            preferences.isPagingVertically = false
            preferences.VerticalPagePadding = false

        case .VERTICAL_SEPARATED:
            preferences.isReadingVertically = true
            preferences.VerticalPagePadding = true
            preferences.isPagingVertically = false

        case .PAGED_VERTICAL:
            preferences.isReadingVertically = false
            preferences.isPagingVertically = true
        }
    }
    
    func setReadingModeForContent(_ value: PanelReadingModes) {
        let id = contentIdentifier
        let container = UserDefaults.standard
        let key = STTKeys.ReaderType + "%%" + id.id
        
        container.setValue(value.rawValue, forKey: key)
    }

    func updateViewerMode(with mode: ReadingMode) {
        guard !setModeToUserSetting() else { return }
        let defaults = UserDefaults.standard
        let preferences = Preferences.standard
        switch mode {
        case .PAGED_MANGA:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = false
            preferences.isPagingVertically = false
            defaults.set(PanelReadingModes.PAGED_MANGA.rawValue, forKey: STTKeys.ReaderType)
        case .PAGED_COMIC:
            preferences.isReadingVertically = false
            preferences.readingLeftToRight = true
            preferences.isPagingVertically = false
            defaults.set(PanelReadingModes.PAGED_COMIC.rawValue, forKey: STTKeys.ReaderType)

        case .VERTICAL:
            preferences.isReadingVertically = true
            preferences.isPagingVertically = false
            preferences.VerticalPagePadding = false
            defaults.set(PanelReadingModes.VERTICAL.rawValue, forKey: STTKeys.ReaderType)

        case .VERTICAL_SEPARATED:
            preferences.isReadingVertically = true
            preferences.VerticalPagePadding = true
            preferences.isPagingVertically = false
            defaults.set(PanelReadingModes.VERTICAL_SEPARATED.rawValue, forKey: STTKeys.ReaderType)

        case .PAGED_VERTICAL:
            preferences.isReadingVertically = false
            preferences.isPagingVertically = true
            defaults.set(PanelReadingModes.PAGED_VERTICAL.rawValue, forKey: STTKeys.ReaderType)

        default: break
        }
    }
}
