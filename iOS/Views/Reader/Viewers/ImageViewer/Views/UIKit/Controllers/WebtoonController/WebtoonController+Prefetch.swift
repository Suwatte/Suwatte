//
//  WebtoonController+Prefetch.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit
import AsyncDisplayKit
fileprivate typealias Controller = WebtoonController

extension Controller {
    func collectionNode(_ collectionNode: ASCollectionNode, willDisplayItemWith node: ASCellNode) {
        let path = node.indexPath
        guard let path else { return }
        
        let data = dataSource.itemIdentifier(for:  path)
        
        guard let data else { return }
        
        guard case .page(let target) = data else { return }
        let page = target.secondaryPage ?? target.page
        let current = page.number
        let count =  page.chapterPageCount
        let chapter =  page.chapter
        let inPreloadRange = count - current < 5
        
        guard inPreloadRange else { return }
        
        Task { [weak self] in
            await self?.preload(after: chapter)
        }
    }

    func preload(after chapter: ThreadSafeChapter) async {
        let index = await dataCache.chapters.firstIndex(of: chapter)
        
        guard let index else { return } // should always pass
        
        let next = await dataCache.chapters.getOrNil(index + 1)
        
        guard let next else { return }
        
        let currentState = model.loadState[next]
        
        guard currentState == nil else { return } // only trigger if the chapter has not been loaded
        
        await load(next)
    }
}
