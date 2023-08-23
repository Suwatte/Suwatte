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

    func pageMarkedAsWide(_ page: ReaderPage) {
        let key = page.CELL_KEY
        guard !widePages.contains(key) else { return }
        widePages.insert(key)
        Task { [weak self] in
            guard let self else { return }
            let key = page.chapter.id
            let updatedPages = await self.build(for: page.chapter)
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: key))
            snapshot.appendItems(updatedPages, toSection: key)
            await MainActor.run { [weak self] in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
                self?.updateChapterScrollRange()
            }
        }
    }
}
