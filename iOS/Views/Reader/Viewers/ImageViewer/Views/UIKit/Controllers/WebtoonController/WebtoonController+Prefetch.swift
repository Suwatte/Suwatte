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
    func shouldBatchFetch(for _: ASCollectionNode) -> Bool {
        guard let currentPath else {
            return false
        }
        
        let index = currentPath.section
        let item = currentPath.item + 1
//        let count = model.sections[index].count
//        return model.readerChapterList.get(index: item) == nil && count - item <= 3
        return false
    }

    func collectionNode(_: ASCollectionNode, willBeginBatchFetchWith context: ASBatchContext) {
//        model.loadNextChapter()
        print("batch fetching")
        context.completeBatchFetching(true)
    }
}
