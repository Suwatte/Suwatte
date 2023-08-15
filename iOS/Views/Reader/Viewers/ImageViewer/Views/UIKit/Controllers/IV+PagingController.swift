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


// MARK: - Tap Gestures
extension Controller {
    
    func addTapGestures() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }
    
    @objc fileprivate func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: view)
        handleNavigation(at: location)
    }

    @objc fileprivate func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }
}


// MARK: Handle Navigation
extension Controller {
    private func handleNavigation(at point: CGPoint) {
        let preferences = Preferences.standard
        let tapToNavigate = preferences.tapSidesToNavigate
        
        guard tapToNavigate else {
            // TODO: Open Menu
            return
        }
        
        var navigator: ReaderNavigation.Modes?

        let isVertical = model.readingMode.isVertical
        
        navigator = isVertical ? preferences.verticalNavigator : preferences.horizontalNavigator
        
        guard let navigator else {
            model.toggleMenu()
            return
        }
        var action = navigator.mode.action(for: point, ofSize: view.frame.size)
        
        if preferences.invertTapSidesToNavigate {
            if action == .LEFT { action = .RIGHT }
            else if action == .RIGHT { action = .LEFT }
        }

        switch action {
        case .MENU:
            model.toggleMenu()
            break
        case .LEFT:
            model.hideMenu()
            moveToPage(next: false)
            
        case .RIGHT:
            model.hideMenu()
            moveToPage()
        }
    }
    
}



// MARK: Transform
extension Controller {
    func setReadingOrder() {
        guard !isVertical else { return }
        collectionView.transform = isInverted ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    }
    
}


extension Controller {
    func subscribeAll() {
        subToSplitPagePublisher()
        subToReadingDirectionPublisher()
        subToSliderPublisher()
        subToScrubEventPublisher()
    }
}

// MARK: State
extension Controller {
    func subToSplitPagePublisher() {
        // Listens for when a page is marked to be split
        guard readingMode.isHorizontalPager else { return }
        PanelPublisher
            .shared
            .willSplitPage
            .sink { page in
                Task { @MainActor [weak self] in
                    self?.split(page)
                }
            }
            .store(in: &subscriptions)
        
        PanelPublisher
            .shared
            .didChangeSplitMode
            .sink { [weak self] in
                // TODO: Fetch and Rebuild Section
            }
            .store(in: &subscriptions)
    }
    
    func subToReadingDirectionPublisher() {
        guard readingMode.isHorizontalPager else { return }
        PanelPublisher
             .shared
             .didChangeHorizontalDirection
             .sink {value in
                 Task { @MainActor [weak self] in
                     self?.setReadingOrder()
                     self?.collectionView.collectionViewLayout.invalidateLayout()
                 }
             }
             .store(in: &subscriptions)
    }
    
    func subToSliderPublisher() {
       PanelPublisher
            .shared
            .sliderPct
            .sink { [weak self] value in
                self?.handleSliderPositionChange(value)
            }
            .store(in: &subscriptions)

    }
    
    
    func subToScrubEventPublisher() {
        PanelPublisher
            .shared
            .didEndScrubbing
            .sink { [weak self] in
                self?.setScrollToCurrentIndex()
            }
            .store(in: &subscriptions)
    }
}


extension Controller {
    
    override func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let path = preRotationPath else {
            return proposedContentOffset
        }
        
        
        let frame = collectionView.layoutAttributesForItem(at: path)?.frame
        
        let value = isVertical ? frame?.minY : frame?.minX
        
        guard let value else {
            return proposedContentOffset
        }
        
        // Reset
        preRotationPath = nil
        
        return .init(x: isVertical ? 0: value,
                     y: isVertical ? value : 0)
    }
    
}


extension Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset)
    }
    
    
    func onUserDidScroll(to point: CGPoint) {
        
        let pos = isVertical ? point.y : point.x
        
        if pos < 0 {
            didTriggerBackTick = true
            return
        }
        
        let difference = abs(pos - lastKnownScrollPosition)
        guard difference >= scrollPositionUpdateThreshold else { return }
        lastKnownScrollPosition = pos
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Only real-time update when the user is not scrubbing & the menu is being shown
            guard !model.slider.isScrubbing && model.control.menu else { return }
//            setScrollPCT(for: pos)
        }
        
    }
}

// MARK: Did Stop Scrolling

extension Controller {
    override func scrollViewDidEndDecelerating(_: UIScrollView) {
        onScrollStop()
    }
    
    override func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        onScrollStop()
    }
    
    override func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        onScrollStop()
    }
    
    func onScrollStop() {
        let currentPath = collectionView.pathAtCenterOfScreen
        
        model.hideMenu()

        
        if didTriggerBackTick {
            Task { [weak self] in
                await self?.loadPrevChapter()
            }
            didTriggerBackTick = false
        }
        
        guard let currentPath else { return }
        
        if currentPath.section != lastIndexPath.section {
            STTHelpers.triggerHaptic()
            let prev = dataSource.itemIdentifier(for: lastIndexPath)?.chapter
            let next = dataSource.itemIdentifier(for: currentPath)?.chapter
            guard let prev, let next else { return }
            didChapterChange(from: prev, to: next)
        } else {
            guard currentPath.item != lastIndexPath.item, let page = dataSource.itemIdentifier(for: currentPath) else { return }
            didChangePage(page)
        }
                
        lastIndexPath = currentPath
        
        Task { @MainActor [weak self] in
            guard let self, !self.model.control.menu else { return }
            self.setScrollPCT(for: self.collectionView.currentPoint.x)
        }
        
    }
}

// MARK: Slider
extension Controller {
    func updateChapterScrollRange() {
        self.currentChapterRange = getScrollRange()
    }
    
    func scrollToPosition(for pct: Double) -> CGFloat {
        let total = currentChapterRange.max - currentChapterRange.min
        var amount = total * pct
        amount += currentChapterRange.min
        return amount
    }
    
    func setScrollPCT(for offset: CGFloat) {
        let contentOffset = isVertical ? collectionView.contentOffset.y : collectionView.contentOffset.x
        let total = currentChapterRange.max - currentChapterRange.min
        var current = contentOffset - currentChapterRange.min
        current = max(0, current)
        current = min(currentChapterRange.max, current)
        let target = Double(current / total)
        
        Task { @MainActor [weak self] in
            self?.model.slider.current = target
        }
    }
    
    func setScrollToCurrentIndex() {
        guard let path = collectionView.pathAtCenterOfScreen else { return }
        collectionView.scrollToItem(at: path, at: isVertical ? .centeredVertically : .centeredHorizontally, animated: true)
    }
}


extension Controller: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}

extension Controller {
    func load(_ chapter: ThreadSafeChapter) async {
        do {
            model.updateChapterState(for: chapter, state: .loading)
            try await dataCache.load(for: chapter)
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
        let s = snapshot
        await MainActor.run { [ weak self] in
            self?.dataSource.apply(s, animatingDifferences: false)
        }
    }
    
    func loadAtHead(_ chapter: ThreadSafeChapter) async {
        model.updateChapterState(for: chapter, state: .loading)
        
        do {
            try await dataCache.load(for: chapter)
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


extension Controller {
    
    func didChangePage(_ item: PanelViewerItem) {
        switch item {
            case .page(let page):
                model.viewerState.chapter = page.page.chapter
                model.viewerState.page = page.page.index + 1
                model.viewerState.pageCount = page.page.chapterPageCount
                // TODO: DB Actions
            case .transition(let transition):
                break
        }
    }
    
    func didChapterChange(from: ThreadSafeChapter, to: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
    }
    
    @MainActor
    func loadPrevChapter() async {
        guard let current = collectionView.currentPath, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let currentReadingIndex = await dataCache.chapters.firstIndex(of: chapter), // Index Relative to ChapterList
              currentReadingIndex != 0, // Is not the first chapter
              let next = await dataCache.chapters.getOrNil(currentReadingIndex - 1), // Next Chapter in List
              model.loadState[next] == nil else { return } // is not already loading/loaded
        
        await loadAtHead(next)
    }
}

extension Controller: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)
        
        guard let indexPath,
              case .page(let page) = dataSource.itemIdentifier(for: indexPath),
              let image = (interaction.view as? UIImageView)?.image
        else { return nil }
        
        let chapter = page.page.chapter
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
            
            // Image Actiosn menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
                ToastManager.shared.info("Panel Saved!")
            }
            
            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }
            
            let photoMenu = UIMenu(title: "", options: .displayInline, children: [saveToAlbum, sharePhotoAction])
            
            var menu = UIMenu(title: "Page \(page.page.index + 1)", children: [photoMenu])
            
            guard !STTHelpers.isInternalSource(chapter.sourceId) else { return menu }
            
            // Bookmark Actions
            
//            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter.toStored(), page: page.page.index)
//            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
//            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"
//
//            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
//                DataManager.shared.toggleBookmark(chapter: chapter.toStored(), page: page.page.index)
//                ToastManager.shared.info("Bookmark \(isBookmarked ? "Removed" : "Added")!")
//            }
            
            menu = menu.replacingChildren([photoMenu])
            return menu
        })
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
    
    
    func initialLoad() async -> (ThreadSafeChapter, IndexPath, CGFloat?)? {
        guard let pendingState = model.pendingState else {
            Logger.shared.warn("calling initialLoad() without any pending state")
            return nil
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
            Logger.shared.warn("load complete but page list is empty", "ImageViewer")
            return nil
        }
        
        let isFirstChapter = chapterIndex == 0
        let requestedPageIndex = (pendingState.pageIndex ?? 0) + (isFirstChapter ? 1 : 0)
        let indexPath = IndexPath(item: requestedPageIndex, section: 0)
        
        model.pendingState = nil // Consume Pending State
        
        return (chapter, indexPath, pendingState.pageOffset.flatMap(CGFloat.init))
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
    
    func getScrollRange() -> (min: CGFloat, max: CGFloat) {
        let def : (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.currentPath else {
            return def
        }
        let snapshot = dataSource.snapshot()
        let item = dataSource.itemIdentifier(for: path)
        guard let item else { return def }
        let section = snapshot.itemIdentifiers(inSection: item.chapter.id)
        
        let minIndex = section.firstIndex(where: \.isPage) // O(1)
        let maxIndex = max(section.endIndex - 2, 0)
        
        // Get Min
        if let minIndex  {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))
            
            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }
        
        // Get Max
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            sectionMaxOffset = attributes.frame.minX
        }
        
        return (min: sectionMinOffset, max: sectionMaxOffset)
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
    
        var next: PanelPage? = nil
        var prepared: [PanelViewerItem] = []
        for item in items {
    
            // Get Page Entries
            guard case .page(let data) = item else {
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



// MARK: - Did End Displaying
extension Controller {
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? CancellableImageCell else { return }
        cell.cancelTasks()
    }
}

// MARK: - Will Display
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


extension Controller {
    func handleSliderPositionChange(_ value: Double) {
        guard model.slider.isScrubbing else {
            return
        }
        let position = scrollToPosition(for: value)
        let point = CGPoint(x: !isVertical ? position : 0,
                            y: isVertical ? position : 0)

        defer {
            collectionView.setContentOffset(point, animated: false)
        }
        guard let path = collectionView.indexPathForItem(at: point),
              case .page(let page) = dataSource.itemIdentifier(for: path) else {
            return
        }
        
        model.viewerState.page = page.page.number
    }
}
