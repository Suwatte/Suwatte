//
//  PagedCoordinator+Setup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import Foundation

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    func setupCollectionView() {
        addTapGestures()
        configureDataSource()
        setReadingOrder()
        listen()
        
    }
    
    func initialLoad() async {
        guard let chapter = await model.loadState.keys.first else {
            Logger.shared.warn("unconsumed setup state", "ImageViewer")
            return
        }
        _ = await load(chapter)
        
        guard let pages = await dataCache.cache[chapter.id],
              let chapterIndex = await dataCache.chapters.firstIndex(of: chapter) else {
            Logger.shared.warn("load complete but page list is empty", "ImageViewer")
            return
        }
        
        let pageIndex = 0
        let path: IndexPath = .init(item: 1, section: 0)
        
        // update chapter info
        let pageCount = pages.count
        
        
        var requestedPageIndex = await model.pendingState?.pageIndex
        if requestedPageIndex == nil {
            requestedPageIndex = chapterIndex == 0 ? 1 : 0
        }
        
        guard let requestedPageIndex else {
            Logger.shared.warn("unable to select a page.", "ImageViewer")
            return
        }
        
        await updateReaderState(with: chapter, page: pageIndex + 1, count: pageCount)
        
        // Update view info
        await MainActor.run {
            lastIndexPath = path
            updateChapterScrollRange()
            collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: false)
            collectionView.isHidden = false
            model.pendingState = nil // Consume Pending
        }
    }
}
