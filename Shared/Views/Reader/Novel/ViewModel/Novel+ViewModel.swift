//
//  Novel+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-31.
//

import Combine
import Foundation
import SwiftUI
import UIKit

extension NovelReaderView {
    final class ViewModel: ObservableObject {
        var chapterList: [ThreadSafeChapter]

        var readerChapterList: [ReaderView.ReaderChapter] = []
        @Published var activeChapter: ReaderView.ReaderChapter
        @Published var updater = false
        var sections: [[NovelPage]] = []
        var counts: [String: Int] = [:]
        @Published var menuControl: ReaderView.MenuControl = .init()
        @Published var slider: ReaderView.SliderControl = .init()
        @Published var toast = ToastManager()
        @Published var scrubbingPageNumber: Int?
        @Published var currentSectionPageNumber = 1

        var subscriptions = Set<AnyCancellable>()

        let reloadSectionPublisher = PassthroughSubject<Int, Never>()
        let insertPublisher = PassthroughSubject<Int, Never>()
        let reloadPublisher = PassthroughSubject<Void, Never>()
        let scrubEndPublisher = PassthroughSubject<Void, Never>()
        let navigationPublisher = PassthroughSubject<ReaderView.ReaderNavigation.NavigationType, Never>()

        init(chapterList: [StoredChapter], openTo chapter: StoredChapter) {
            // Sort Chapter List by either sourceIndex or chapter number
            let sourceIndexAcc = chapterList.map { $0.index }.reduce(0, +)
            self.chapterList = (sourceIndexAcc > 0 ? chapterList.sorted(by: { $0.index > $1.index }) : chapterList.sorted(by: { $0.number > $1.number }))
                .map { $0.toThreadSafe() }

            activeChapter = .init(chapter: chapter.toThreadSafe())
            activeChapter.requestedPageIndex = -1
            readerChapterList.append(activeChapter)
            listen()
        }

        func loadChapter(_ chapter: ThreadSafeChapter, asNextChapter: Bool = true) async {
            let alreadyInList = readerChapterList.contains(where: { $0.chapter._id == chapter._id })
            let readerChapter: ReaderView.ReaderChapter?

            readerChapter = alreadyInList ? readerChapterList.first(where: { $0.chapter._id == chapter._id })! : ReaderView.ReaderChapter(chapter: chapter)

            guard let readerChapter = readerChapter else {
                return
            }

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
                case .loaded(let t):
                    readerChapter.data = .loaded(t.toReadableChapterData())
                case .failed(let error):
                    readerChapter.data = .failed(error)
                default: break
            }
//            notifyOfChange()

            guard let data = readerChapter.data.value else {
                return
            }

            let newPages = await Task { @MainActor in
                return generateViews(for: data, title: chapter.displayName)
            }.value

            if asNextChapter {
                sections.append(newPages)
            } else {
                sections.insert(newPages, at: 0)
            }

            // Set Opening Page
            if readerChapterList.count == 1, readerChapter.requestedPageIndex == -1 {
                let values = STTHelpers.getInitialPosition(for: readerChapter.chapter, limit: getPageCount())
                readerChapter.requestedPageIndex = values.0
                readerChapter.requestedPageOffset = values.1
            }
            
            if readerChapterList.count == 1 {
                reloadPublisher.send()
            } else {
                insertPublisher.send(asNextChapter ? sections.count - 1 : 0)
            }
            
            notifyOfChange()
            if newPages.isEmpty {
                loadNextChapter()
            }
        }

        func notifyOfChange() {
            Task { @MainActor in
                updater.toggle()
            }
        }
        
        func getPageCount() -> Int {
            counts[activeChapter.chapter._id] ?? 0
        }
    }
}

extension NovelReaderView.ViewModel {
    func generateViews(for chapter: ReaderView.ChapterData, title: String) -> [NovelPage] {
        var pages = [NovelPage]()
        let text = chapter.text ?? "No Text Returned from Source"
        let joined = "\(title )\n\n" + text + "\n"
        var textStorage: NSTextStorage?
        let data = Data(joined.utf8)
        if let attributedString = try? NSAttributedString(data: data,
                                                          options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                                                          documentAttributes: nil)
        {
            textStorage = .init(attributedString: attributedString)
        } else {
            textStorage = NSTextStorage(string: text)
        }

        let textLayout = NSLayoutManager()
        textStorage?.addLayoutManager(textLayout)

        var lastRenderedGlyph = 0
        let topInset = KEY_WINDOW?.safeAreaInsets.top ?? 0
        let bottomInset = KEY_WINDOW?.safeAreaInsets.bottom ?? 0
        let size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - topInset - bottomInset)

        while lastRenderedGlyph < textLayout.numberOfGlyphs {
            let textContainer = NSTextContainer(size: size)
            textLayout.addTextContainer(textContainer)

            let textView = UITextView(frame: .init(x: 0, y: 0, width: size.width, height: size.height), textContainer: textContainer)

            textView.isScrollEnabled = false
            textView.isUserInteractionEnabled = false
            textView.backgroundColor = .clear

            let useSystemColor = Preferences.standard.novelUseSystemColor

            textView.textColor = useSystemColor ? .init(Color.primary) : .init(Color(rawValue: UserDefaults.standard.string(forKey: STTKeys.NovelFontColor) ?? "") ?? .white)
            textView.isSelectable = true

            let font = Preferences.standard.novelFont
            let size = CGFloat(Preferences.standard.novelFontSize)
            textView.font = UIFont(name: font, size: size) ?? UIFont(name: "Georgia", size: size)
            // get the last Glyph rendered into the current textContainer
            let range = textLayout.glyphRange(for: textContainer)
            lastRenderedGlyph = NSMaxRange(range)

            textView.backgroundColor = .clear

//            let lowerBound = joined.index(joined.startIndex, offsetBy: range.lowerBound)
//            let upperBound = joined.index(joined.startIndex, offsetBy: range.upperBound)
////            let pagedText = joined[lowerBound ..< upperBound]
//
//            let prevLastIndex = pages.last?.lastPageIndex ?? 0

//            let unusedPages = chapter.pages[prevLastIndex...]
            let lastIndex = 0
            pages.append(.init(view: textView, lastPageIndex: lastIndex))
        }
        // Update Last Page To Match the Last Page Index
        let lastIndex = pages.count - 1
        pages[lastIndex] = .init(view: pages[lastIndex].view, lastPageIndex: chapter.pages.count - 1)
        counts[chapter.id] = pages.count
        return pages
    }

    func getPage(at path: IndexPath) -> NovelPage {
        sections[path.section][path.item]
    }

    func updatedPreferences() {
        let current = activeChapter
        sections.removeAll()
        readerChapterList.removeAll()
        readerChapterList.append(current)
        guard let data = current.data.value else {
            return
        }
        Task { @MainActor in
            let newPages = generateViews(for: data, title: current.chapter.displayName)
            sections.append(newPages)
            reloadPublisher.send()
        }
    }

    func listen() {
        let targets = [\Preferences.novelBGColor, \.novelFontSize, \.novelFontColor, \.novelUseVertical, \.novelOrientationLock, \.novelUseSystemColor, \.novelUseDoublePaged]
        
        Preferences.standard.preferencesChangedSubject
            .filter { path in
                guard let path = path as? PartialKeyPath<Preferences> else { return false }
                return targets.contains(path)
            }
            .sink { [weak self] _ in
                self?.updatedPreferences()
            }
            .store(in: &subscriptions)

        toast.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &subscriptions)
    }

    func getChapterIndex(_ chapter: ThreadSafeChapter) -> Int {
        chapterList.firstIndex(where: { $0 == chapter })!
    }

    func loadNextChapter() {
        guard let lastChapter = readerChapterList.last?.chapter, let nextChapter = chapterList.get(index: getChapterIndex(lastChapter) + 1) else {
            return
        }
        Task { @MainActor in
            await loadChapter(nextChapter)
        }
    }

    func loadPreviousChapter() {
        guard let lastChapter = readerChapterList.first?.chapter, let target = chapterList.get(index: getChapterIndex(lastChapter) - 1) else {
            return
        }

        Task { @MainActor in
            await loadChapter(target, asNextChapter: false)
        }
    }
}

extension NovelReaderView.ViewModel {
    func didScrollTo(path: IndexPath) {
        currentSectionPageNumber = path.item + 1
        let chapter = readerChapterList.get(index: path.section)
        guard let chapter = chapter else {
            return
        }
        let index = path.item
        if chapter !== activeChapter {
            DataManager.shared.setNovelProgress(from: chapter, pageCount: getPageCount())
            onChapterChanged(chapter: chapter)
            return
        }
        // On Same Page, Do Nothing
        if index == activeChapter.requestedPageIndex { return }

        // Page Changed, Handle Page Change Logic
        onPageChanged(index: index, chapter: chapter)
    }

    private var incognitoMode: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.incognito)
    }

    private func onPageChanged(index: Int, chapter: ReaderView.ReaderChapter) {
        activeChapter.requestedPageIndex = index
        if incognitoMode { return }

        // Save Progress
        DataManager.shared.setNovelProgress(from: chapter, pageCount: getPageCount())

        // Update Entry Last Read
        if let content = content {
            DataManager.shared.updateLastRead(forId: content._id)
        }
    }

    private func onChapterChanged(chapter: ReaderView.ReaderChapter) {
        let lastChapter = activeChapter
        activeChapter = chapter
        ToastManager.shared.info("Now Reading \(activeChapter.chapter.displayName)")

        if incognitoMode { return }

        // Moving to Previous Chapter, Do Not Mark as Completed
        if lastChapter.chapter.number > chapter.chapter.number {
            return
        }

        // Trackers
        let trackerInfo = getTrackerInfo(ContentIdentifier(contentId: lastChapter.chapter.contentId, sourceId: lastChapter.chapter.sourceId).id)
        let chapterNumber = Int(lastChapter.chapter.number)
        var chapterVolume: Int?
        if let vol = lastChapter.chapter.volume {
            chapterVolume = Int(vol)
        }
        let vol = chapterVolume
        Task {
            // Anilist
            do {
                try await STTHelpers.syncToAnilist(mediaID: trackerInfo?.al, progress: chapterNumber, progressVolume: vol)
            } catch {
                Logger.shared.error("[Novel VM] [Anilist] \(error)")
            }
        }

        // Services
        let source = DaisukeEngine.shared.getJSSource(with: lastChapter.chapter.sourceId)
        let contentId = lastChapter.chapter.contentId
        let chapterId = lastChapter.chapter.chapterId
        Task {
            await source?.onChapterRead(contentId: contentId, chapterId: chapterId)
        }
    }

    var content: StoredContent? {
        let chapter = activeChapter.chapter
        return DataManager.shared.getStoredContent(chapter.sourceId, chapter.contentId)
    }

    var title: String {
        content?.title ?? ""
    }

    private func getTrackerInfo(_: String) -> StoredTrackerInfo? {
//        content?.trackerInfo ?? DataManager.shared.getTrackerInfo(id)
        return nil
    }

    func handleNavigation(_ point: CGPoint) {
        // Get Action
        let navigator = STTHelpers.getNavigationMode()
        let action = navigator.mode.action(for: point, ofSize: UIScreen.main.bounds.size)

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

    struct NovelPage {
        var view: UITextView
        var lastPageIndex: Int
    }
}
