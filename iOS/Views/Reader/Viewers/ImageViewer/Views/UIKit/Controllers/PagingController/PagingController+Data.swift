//
//  PagingController+Data.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import Foundation

private typealias Controller = IVPagingController

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

    func apply(_ chapter: ThreadSafeChapter) async {
        let pages = await build(for: chapter)
        let id = chapter.id
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([id])
        snapshot.appendItems(pages, toSection: id)
        await MainActor.run { [weak self, snapshot] in
            self?.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    func loadAtHead(_ chapter: ThreadSafeChapter) async {
        model.updateChapterState(for: chapter, state: .loading)

        do {
            try await dataCache.load(for: chapter)
            model.updateChapterState(for: chapter, state: .loaded(true))
            let pages = await build(for: chapter)
            var snapshot = dataSource.snapshot()
            let head = snapshot.sectionIdentifiers.first

            guard let head else {
                return
            }

            snapshot.insertSections([chapter.id], beforeSection: head)
            snapshot.appendItems(pages, toSection: chapter.id)
            let s = snapshot
            await MainActor.run { [weak self] in
                self?.preparingToInsertAtHead()
                self?.dataSource.apply(s, animatingDifferences: false)
            }
        } catch {
            Logger.shared.error(error)
            model.updateChapterState(for: chapter, state: .failed(error))
            ToastManager.shared.error("Failed to load chapter.")
        }
    }
}

extension Controller {
    func build(for chapter: ThreadSafeChapter) async -> [PanelViewerItem] {
        return await isDoublePager ? buildDoublePaged(for: chapter) : buildSingles(for: chapter)
    }

    func buildAndApply(_ chapter: ThreadSafeChapter) async {
        let pages = await build(for: chapter)

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([chapter.id])
        snapshot.appendItems(pages, toSection: chapter.id)
        let s = snapshot
        await MainActor.run { [weak self] in
            self?.dataSource.apply(s, animatingDifferences: false)
        }
    }

    func initialLoad() async {
        guard let pendingState = model.pendingState else {
            Logger.shared.warn("calling initialLoad() without any pending state", "PagingController")
            return
        }
        let chapter = pendingState.chapter
        let isLoaded = model.loadState[chapter] != nil

        if !isLoaded {
            // Load Chapter Data
            _ = await load(chapter)
        } else {
            // Data has already been loaded, just apply instead
            await apply(chapter)
        }

        // Retrieve chapter data
        guard let chapterIndex = await dataCache.chapters.firstIndex(of: chapter) else {
            Logger.shared.warn("load complete but page list is empty", "PagingController")
            return
        }

        guard let page = await dataCache.get(chapter.id)?.getOrNil(pendingState.pageIndex ?? 0) else {
            Logger.shared.warn("Unable to get the requested page or the first page in the chapter", "PagingController")
            return
        }
        model.updateViewerStateChapter(chapter)
        model.updateViewerState(with: page)

        var path = IndexPath(item: 0, section: 0)

        if !isDoublePager {
            let isFirstChapter = chapterIndex == 0
            let requestedPageIndex = (pendingState.pageIndex ?? 0) + (isFirstChapter ? 1 : 0)
            path = IndexPath(item: requestedPageIndex, section: 0)
        } else {
            let snapshot = dataSource.snapshot().itemIdentifiers(inSection: chapter.id)
            let index = snapshot.firstIndex { item in
                guard case let .page(v) = item else {
                    return false
                }
                let index = v.secondaryPage?.index ?? v.page.index
                return index == (pendingState.pageIndex ?? 0)
            }

            if let index {
                path.item = index
            }
        }
        await MainActor.run {
            model.pendingState = nil // Consume Pending State
            lastIndexPath = path
            collectionView.scrollToItem(at: path,
                                        at: isVertical ? .centeredVertically : .centeredHorizontally,
                                        animated: false)
            updateChapterScrollRange()
            setScrollPCT()
            collectionView.isHidden = false
            self.isLoaded = true
        }
    }

    func split(_ page: PanelPage) {
        var snapshot = dataSource.snapshot()

        var secondary = page
        secondary.isSplitPageChild = true
        snapshot.insertItems([.page(secondary)], afterItem: .page(page))

        let s = snapshot
        Task { @MainActor [weak self] in
            self?.dataSource.apply(s, animatingDifferences: false)
        }
    }

    func moveToPage(next: Bool = true) {
        func moveVertical() -> IndexPath? {
            let height = collectionView.frame.height
            let offset = !next ? collectionView.currentPoint.y - height : collectionView.currentPoint.y + height

            let path = collectionView.indexPathForItem(at: .init(x: 0, y: offset))
            return path
        }

        func moveHorizontal() -> IndexPath? {
            let width = collectionView.frame.width
            let offset = !next ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width

            let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

            return path
        }
        let path = isVertical ? moveVertical() : moveHorizontal()
        guard let path else { return }
        collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
    }

    func preparingToInsertAtHead() {
        let layout = collectionView.collectionViewLayout as? OffsetPreservingLayout
        layout?.isInsertingCellsToTop = true
    }
}

extension Controller {
    func buildSingles(for chapter: ThreadSafeChapter) async -> [PanelViewerItem] {
        await dataCache.prepare(chapter.id) ?? []
    }

    func buildDoublePaged(for chapter: ThreadSafeChapter) async -> [PanelViewerItem] {
        let items = await dataCache.prepare(chapter.id)
        guard let items else {
            Logger.shared.warn("page cache empty, please call the load method")
            return []
        }

        var next: PanelPage?
        var prepared: [PanelViewerItem] = []
        for item in items {
            // Get Page Entries
            guard case let .page(data) = item else {
                // single lose next page, edge case where these is a single page before the last transition
                if let next {
                    prepared.append(.page(next))
                }

                prepared.append(item)
                continue
            }

            if item == items.first(where: \.isPage) {
                prepared.append(item)
                continue
            }

            // marked as wide, add next if exists & reset
            if widePages.contains(data.page.CELL_KEY) {
                if let next {
                    prepared.append(.page(next))
                }
                prepared.append(item)
                next = nil
                continue
            }

            // next page exists, secondary is nil
            if var val = next {
                val.secondaryPage = data.page
                prepared.append(.page(val))
                next = nil
                continue
            }

            if item == items.last {
                prepared.append(item)
            } else {
                next = data
            }
        }
        return prepared
    }
}

extension Controller {
    @MainActor
    func loadPrevChapter() async {
        guard let current = collectionView.currentPath, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let prev = await dataCache.getChapter(before: chapter), // Prev Chapter
              model.loadState[prev] == nil else { return } // is not already loading/loaded

        await loadAtHead(prev)
    }
}

extension Controller {
    func reload(removeSplits: Bool) async {
        let chapter = model.viewerState.chapter
        var snapshot = dataSource.snapshot()

        if removeSplits {
            let items = snapshot.itemIdentifiers(inSection: chapter.id).filter { item in
                guard case let .page(page) = item else { return false }
                return page.isSplitPageChild
            }

            snapshot.deleteItems(items)
        } else {
            snapshot.reloadSections([chapter.id])
        }

        await MainActor.run { [weak self, snapshot] in
            self?.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
}
