//
//  IV+PagingController.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-08.
//

import UIKit
import Combine

extension Hashable {
    func isIn(_ set : Set<Self>) -> Bool {
        set.contains(self)
    }
}


class IVPagingController: UICollectionViewController {
    internal var preRotationPath: IndexPath?
    internal var subscriptions = Set<AnyCancellable>()
    internal var lastIndexPath: IndexPath = .init(item: 0, section: 0)
    internal var currentChapterRange: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
    internal var didTriggerBackTick = false
    internal var lastKnownScrollPosition: CGFloat = 0.0
    internal var scrollPositionUpdateThreshold: CGFloat = 20.0
    internal var dataSource: UICollectionViewDiffableDataSource<String, PanelViewerItem>!
    internal var widePages: Set<String> = []
    var model: IVViewModel!
    
    var isVertical = false
    var isDoublePager = false
    
    var dataCache: IVDataCache {
        model.dataCache
    }
    
    var isInverted: Bool {
        model.readingMode.isInverted
    }
    
    var readingMode: ReadingMode {
        model.readingMode
    }
    
    deinit {
        Logger.shared.debug("IVPagingController deallocated")
    }

}

typealias IVCC = IVPagingController

fileprivate typealias Controller = IVPagingController


extension Controller {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // General
        collectionView.isPagingEnabled = true
        collectionView.isHidden = true
        collectionView.scrollsToTop = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        
        // Layout Specific
        let layout = isVertical ? VImageViewerLayout() : HImageViewerLayout()
        collectionView.setCollectionViewLayout(layout, animated: false)
        
        // Final setup calls
        setReadingOrder()
        addTapGestures()
        subscribeAll()
        configureDataSource()
        
        // start 
        startup()
    }
    func updateReaderState(with chapter: ThreadSafeChapter, indexPath: IndexPath, offset: CGFloat?) async {
        let hasNext = await dataCache.getChapter(after: chapter) != nil
        let hasPrev = await dataCache.getChapter(before: chapter) != nil
        let pages = await dataCache.cache[chapter.id]?.count
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let pages, case .page(let page) = item else {
            Logger.shared.warn("invalid reader state", "updateReaderState")
            return
        }
        
        let state: CurrentViewerState = .init(chapter: chapter,
                                              page: page.page.number,
                                              pageCount: pages,
                                              hasPreviousChapter: hasPrev,
                                              hasNextChapter: hasNext)
        
        model.setViewerState(state)
    }
    
    func startup() {
        Task { [weak self] in
            guard let self else { return }
            let state = await self.initialLoad()
            guard let state else { return }
            let (chapter, path, offset) = state
            await self.updateReaderState(with: chapter, indexPath: path, offset: offset)
            await MainActor.run { [weak self] in
                self?.didFinishInitialLoad(chapter, path)
            }
        }
    }
}

extension Controller {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        preRotationPath = collectionView.currentPath
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }
    
}


extension Controller {
    
    func didFinishInitialLoad(_ chapter: ThreadSafeChapter, _ path: IndexPath) {
        lastIndexPath = path
        updateChapterScrollRange()
        model.slider.current = 0.0
        collectionView.scrollToItem(at: path, at: isVertical ? .centeredVertically : .centeredHorizontally, animated: false)
        collectionView.isHidden = false
    }
}




// MARK: Transform
extension Controller {
    func setReadingOrder() {
        guard !isVertical else { return }
        collectionView.transform = isInverted ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }
}

extension Controller: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}

// MARK: Data Source
extension Controller {
    func configureDataSource() {
        let SingleImageCellRegistration = UICollectionView.CellRegistration<PagedViewerImageCell, PanelPage> { [weak self] cell, indexPath, data in
            cell.set(page: data, delegate: self)
            cell.setImage()
        }
        
        let DoubleImageCellRegistration = UICollectionView.CellRegistration<DoublePagedViewerImageCell, PanelPage> { [weak self] cell, indexPath, data in
            cell.set(page: data, delegate: self)
            cell.setImage()
        }
        
        let TransitionCellRegistration = UICollectionView.CellRegistration<TransitionCell, ReaderTransition> { cell, indexPath, data in
            cell.configure(data)
        }
        
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            collectionView, indexPath, item -> UICollectionViewCell in
            switch item {
            case .page(let page):
                if page.secondaryPage == nil {
                    return collectionView.dequeueConfiguredReusableCell(using: SingleImageCellRegistration, for: indexPath, item: page)
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: DoubleImageCellRegistration, for: indexPath, item: page)
                }
                
            case .transition(let transition):
                return collectionView.dequeueConfiguredReusableCell(using: TransitionCellRegistration, for: indexPath, item: transition)
            }
        }
    }

}


// MARK: - Did End Displaying / Task Cancellation
extension Controller {
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? CancellableImageCell else { return }
        cell.cancelTasks()
    }
}

// MARK: - Will Display / Chapter Preloading
extension Controller {
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let data = dataSource.itemIdentifier(for:  indexPath)
        
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


