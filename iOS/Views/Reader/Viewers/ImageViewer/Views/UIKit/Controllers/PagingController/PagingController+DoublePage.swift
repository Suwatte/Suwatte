//
//  PagingController+DoublePage.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import Foundation

private typealias Controller = IVPagingController

extension Controller: DoublePageResolverDelegate {
    func primaryIsWide(for page: PanelPage) {
        pageMarkedAsWide(page.page)
    }

    func secondaryIsWide(for page: PanelPage) {
        guard let target = page.secondaryPage else {
            Logger.shared.warn("requesting to mark a secondary page that is not defined")
            return
        }
        pageMarkedAsWide(target)
    }

    func pageMarkedAsWide(_ page: ReaderPage, navigate: Bool = false) {
        let key = page.CELL_KEY
        guard !widePages.contains(key) else { return }
        widePages.insert(key)
        rebuild(chapter: page.chapter, to: navigate ? page : nil)
    }

    func pageUnmarkedAsWide(_ page: ReaderPage, navigate: Bool = false) {
        let key = page.CELL_KEY
        guard widePages.contains(key) else { return }
        widePages.remove(key)
        rebuild(chapter: page.chapter, to: navigate ? page : nil)
    }

    func rebuild(chapter: ThreadSafeChapter, to page: ReaderPage? = nil) {
        Task { [weak self] in
            guard let self else { return }
            let key = chapter.id
            let updatedPages = await self.build(for: chapter)
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: key))
            snapshot.appendItems(updatedPages, toSection: key)
            await MainActor.run { [weak self] in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
                self?.updateChapterScrollRange()
                if let page {
                    self?.navigate(to: page)
                }
            }
        }
    }

    func navigate(to page: ReaderPage) {
        let snapshot = dataSource.snapshot().itemIdentifiers(inSection: page.chapter.id)
        let sectionIndex = dataSource.snapshot().sectionIdentifiers.firstIndex(of: page.chapter.id)
        let index = snapshot.firstIndex { item in
            guard case let .page(v) = item else {
                return false
            }
            let index = v.secondaryPage?.index ?? v.page.index
            return index == page.index
        }

        guard let index, let sectionIndex else { return }
        collectionView.scrollToItem(at: .init(item: index, section: sectionIndex),
                                    at: isVertical ? .centeredVertically : .centeredHorizontally,
                                    animated: true)
    }
}
