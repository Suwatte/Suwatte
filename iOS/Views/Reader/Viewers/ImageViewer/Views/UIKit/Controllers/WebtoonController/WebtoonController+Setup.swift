//
//  WebtoonController+Setup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-19.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func startup() {
        Task { [weak self] in
            guard let self else { return }
            await self.initialLoad()
        }
    }

    func initialLoad() async {
        guard let pendingState = model.pendingState else {
            Logger.shared.warn("calling initialLoad() without any pending state")
            return
        }
        let chapter = pendingState.chapter
        let isLoaded = model.loadState[chapter] != nil

        if let index = pendingState.pageIndex, let offset = pendingState.pageOffset {
            resumptionPosition = (index, offset)
        }

        if !isLoaded {
            // Load Chapter Data
            _ = await load(chapter)
        } else {
            // Data has already been loaded, just apply instead
            await apply(chapter)
        }

        // Retrieve chapter data
        guard let chapterIndex = await dataCache.chapters.firstIndex(of: chapter) else {
            Logger.shared.warn("load complete but page list is empty", "ImageViewer")
            return
        }

        guard let page = await dataCache.get(chapter.id)?.getOrNil(pendingState.pageIndex ?? 0) else {
            Logger.shared.warn("Unable to get the requested page or the first page in the chapter", "WebtoonController")
            return
        }
        model.updateViewerStateChapter(chapter)
        model.updateViewerState(with: page)

        let isFirstChapter = chapterIndex == 0
        let requestedPageIndex = (pendingState.pageIndex ?? 0) + (isFirstChapter ? 1 : 0)
        let indexPath = IndexPath(item: requestedPageIndex, section: 0)
        await MainActor.run {
            model.pendingState = nil // Consume Pending State
            lastIndexPath = indexPath
            collectionNode.scrollToItem(at: indexPath, at: .top, animated: false)
            updateChapterScrollRange()
            setScrollPCT()
            presentNode()
            lastKnownScrollPosition = offset
            lastStoppedScrollPosition = offset
            hasCompletedInitialLoad = true
        }
    }
}

extension Controller {
    func load(_ chapter: ThreadSafeChapter) async {
        do {
            model.updateChapterState(for: chapter, state: .loading)
            try await dataCache.load(for: chapter)
            model.updateChapterState(for: chapter, state: .loaded(true))
            await apply(chapter)
        } catch {
            Logger.shared.error(error)
            model.updateChapterState(for: chapter, state: .failed(error))
            return
        }
    }

    @MainActor
    func loadPrevChapter() async {
        guard let current = pathAtCenterOfScreen, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let prev = await dataCache.getChapter(before: chapter), // Prev Chapter in List
              model.loadState[prev] == nil else { return } // is not already loading/loaded

        await loadAtHead(prev)
    }

    func loadAtHead(_ chapter: ThreadSafeChapter) async {
        model.updateChapterState(for: chapter, state: .loading)

        do {
            try await dataCache.load(for: chapter)
            model.updateChapterState(for: chapter, state: .loaded(true))
            let pages = await build(for: chapter)

            let id = chapter.id
            dataSource.sections.insert(id, at: 0)
            dataSource.appendItems(pages, to: id)
            let section = 0
            let paths = pages.indices.map { IndexPath(item: $0, section: section) }
            let set = IndexSet(integer: section)

            preparingToInsertAtHead()
            await collectionNode.performBatch(animated: false) { [weak self] in
                self?.collectionNode.insertSections(set)
                self?.collectionNode.insertItems(at: paths)
            }

        } catch {
            Logger.shared.error(error)
            model.updateChapterState(for: chapter, state: .failed(error))
            ToastManager.shared.error("Failed to load chapter.")
        }
    }
}

extension Controller {
    func apply(_ chapter: ThreadSafeChapter) async {
        let pages = await build(for: chapter)

        let id = chapter.id
        dataSource.appendSections([id])
        dataSource.appendItems(pages, to: id)
        let section = dataSource.sections.count - 1
        let paths = pages.indices.map { IndexPath(item: $0, section: section) }
        let set = IndexSet(integer: section)
        DispatchQueue.main.async { [weak self] in
            self?.collectionNode.performBatch(animated: false) { [weak self] in
                self?.collectionNode.insertSections(set)
                self?.collectionNode.insertItems(at: paths)
            }
        }
    }

    func build(for chapter: ThreadSafeChapter) async -> [PanelViewerItem] {
        await dataCache.prepare(chapter.id) ?? []
    }

    func preparingToInsertAtHead() {
        let layout = collectionNode.view.collectionViewLayout as? OffsetPreservingLayout
        layout?.isInsertingCellsToTop = true
    }
}
