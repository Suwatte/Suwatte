//
//  WebtoonController+Prefetch.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import AsyncDisplayKit
import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func collectionNode(_: ASCollectionNode, willDisplayItemWith node: ASCellNode) {
        let path = node.indexPath
        guard let path else { return }

        let data = dataSource.itemIdentifier(for: path)

        guard let data else { return }

        guard case let .page(target) = data else { return }
        let page = target.secondaryPage ?? target.page
        let current = page.number
        let count = page.chapterPageCount
        let chapter = page.chapter
        let inPreloadRange = count - current < 5

        guard inPreloadRange else { return }

        Task { [weak self] in
            await self?.preload(after: chapter)
        }
    }

    func preload(after chapter: ThreadSafeChapter) async {
        let next = await dataCache.getChapter(after: chapter)

        guard let next else { return }

        let currentState = model.loadState[next]

        guard currentState == nil else { return } // only trigger if the chapter has not been loaded

        await load(next)
    }
}
