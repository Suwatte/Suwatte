//
//  Vertical+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-13.
//

import Combine
import SwiftUI
import UIKit
enum ScrollDirection {
    case up, down
}

extension VerticalViewer {
    final class VerticalController: UICollectionViewController {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: currentPoint)
        }

        var selectedIndexPath: IndexPath!
        let dlgt = ZoomTransitioningDelegate()
        var lastScrollDirection: ScrollDirection = .down
        var isScrolling: Bool = false
        var enableInteractions: Bool = Preferences.standard.imageInteractions

        var cache: [Int: [Int: CGFloat]] = [:]
        var prefetcher: ImagePrefetcher?

        deinit {
            Logger.shared.debug("Vertical Controller Deallocated")
        }
    }
}

private typealias VerticalController = VerticalViewer.VerticalController
extension VerticalController {
    var currentPoint: CGPoint {
        .init(x: collectionView.frame.midX, y: collectionView.contentOffset.y + collectionView.frame.midY)
    }
}

// MARK: View Controller

private typealias ImageCell = VerticalImageCell

extension VerticalController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setCollectionView()
        registerCells()
        addModelSubscribers()
        navigationController?.delegate = dlgt
        navigationController?.isNavigationBarHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if model.IN_ZOOM_VIEW {
            model.IN_ZOOM_VIEW = false
            return
        }

        guard let rChapter = model.readerChapterList.first else {
            return
        }
        let requestedIndex = rChapter.requestedPageIndex
        let openingIndex = model.sections[0].firstIndex(where: { ($0 as? ReaderView.Page)?.index == requestedIndex }) ?? requestedIndex
        let path: IndexPath = .init(item: openingIndex, section: 0)
        collectionView.scrollToItem(at: path, at: .top, animated: false)

        let point = collectionView.layoutAttributesForItem(at: path)?.frame.minY ?? 0
        model.slider.setCurrent(point)
        calculateCurrentChapterScrollRange()

        // TODO: Last Offset
//        if let lastOffset = rChapter.requestedPageOffset {
//            collectionView.contentOffset.y += lastOffset
//            print("Added", lastOffset)
//
//        }
        collectionView.isHidden = false
    }

    func registerCells() {
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
        collectionView.register(ReaderView.TransitionCell.self, forCellWithReuseIdentifier: ReaderView.TransitionCell.identifier)
    }

    func setCollectionView() {
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        collectionView.isPagingEnabled = false
        collectionView.scrollsToTop = false
        collectionView.isHidden = true
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }

    func getLayout() -> UICollectionViewLayout {
        let layout = VerticalContentOffsetPreservingLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
        layout.estimatedItemSize = .zero
        return layout
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: view)
        model.handleNavigation(location)
    }

    @objc func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }
}

// MARK: Subscriptions

extension VerticalController {
    func addModelSubscribers() {
        // MARK: Reload

        model.reloadPublisher.sink { [weak self] in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
                self?.collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .top, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Scrub End

        model.scrubEndPublisher.sink { [weak self] in
            self?.onScrollStop()
        }
        .store(in: &subscriptions)

        // MARK: Insert

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in
                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? VerticalContentOffsetPreservingLayout
                let topInsertion = section == 0 && model.sections.count != 0
                layout?.isInsertingCellsToTop = topInsertion

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if topInsertion {
                    moveCache()
                }
                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)

        // MARK: Slider

        model.$slider.sink { [weak self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: 0, y: slider.current)
                self?.collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in
            var currentOffset = collectionView.contentOffset.y
            let amount = UIScreen.main.bounds.height * 0.66
            switch action {
            case .LEFT: currentOffset -= amount
            case .RIGHT: currentOffset += amount
            default: return
            }

            if action == .LEFT, currentOffset < 0 {
                currentOffset = 0
            } else if action == .RIGHT, currentOffset >= collectionView.contentSize.height - collectionView.frame.height {
                currentOffset = collectionView.contentSize.height - collectionView.frame.height
            }
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.init(x: 0, y: currentOffset), animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Preference Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.forceTransitions ||
                    changedKeyPath == \Preferences.imageInteractions
            }.sink { [weak self] _ in
                self?.collectionView.reloadData()
            }.store(in: &subscriptions)

        // MARK: User Default

        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.imageInteractions == $0 }
            .sink { [weak self] _ in
                self?.enableInteractions = Preferences.standard.imageInteractions
            }
            .store(in: &subscriptions)
    }
}

// MARK: CollectionView Sections

extension VerticalController {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        model.sections[section].count
    }
}

// MARK: Will & DID End Display

extension VerticalController {
    override func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        Task {
            handleChapterPreload(at: indexPath)
        }

        if let cell = cell as? ImageCell, cell.downloadTask == nil, cell.imageView.image == nil, cell.indexPath == indexPath {
            cell.setImage()
        }
    }

    override func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt _: IndexPath) {
        guard let cell = cell as? ImageCell else {
            return
        }
        cell.cancelTasks()
        KingfisherManager.shared.cache.memoryStorage.remove(forKey: cell.page.CELL_KEY)
        if let url = cell.page.hostedURL {
            KingfisherManager.shared.cache.memoryStorage.remove(forKey: url)
        }
    }
}

// MARK: CollectionView Cells

extension VerticalController {
    override func viewDidLayoutSubviews() {
        if !isScrolling {
            super.viewDidLayoutSubviews()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Cell Logic
        let data = model.getObject(atPath: indexPath)

        if let data = data as? ReaderView.Page {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell

            cell.page = data
            cell.zoomDelegate = self
            cell.resizeDelegate = self
            cell.indexPath = indexPath
            cell.setupViews()

            // Enable Interactions
            if enableInteractions {
                cell.imageView.addInteraction(UIContextMenuInteraction(delegate: self))
            }
            cell.setImage()
            cell.backgroundColor = .clear
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderView.TransitionCell.identifier, for: indexPath) as! ReaderView.TransitionCell
        cell.configure(data as! ReaderView.Transition)
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: Chapter Preloading

extension VerticalController {
    func handleChapterPreload(at path: IndexPath) {
        guard let currentPath = currentPath, currentPath.section == path.section else {
            return
        }

        if currentPath.item < path.item {
            let preloadNext = model.sections[path.section].count - path.item + 1 < 5
            if preloadNext, model.readerChapterList.get(index: path.section + 1) == nil {
                model.loadNextChapter()
            }
        }
    }
}

// MARK: Sizing

import Kingfisher
import SwiftUI
extension VerticalController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let defaultHeight = collectionView.frame.height * 0.66
        let height = cache[indexPath.section]?[indexPath.item]
        return .init(width: collectionView.frame.size.width, height: height ?? defaultHeight)
    }

    func moveCache() {
        let keys = cache.keys.reversed()

        for key in keys {
            cache[key + 1] = cache[key]
        }
        cache[0] = [:]
    }
}

// MARK: Resizing

extension VerticalController: ResizeDelegate {
    func didLoadImage(at path: IndexPath, with size: CGSize) {
        guard cache[path.section]?[path.item] == nil else {
            return
        }
        if cache[path.section] == nil {
            cache[path.section] = [:]
        }
        let size = size.scaledTo(collectionView.frame.size)
        cache[path.section]?.updateValue(size.height, forKey: path.item)

        let attributes = collectionView.layoutAttributesForItem(at: path)
        guard let attributes = attributes else {
            return
        }
        let origin = attributes.frame.origin

//        // Set Offset Position
        let layout = collectionView.collectionViewLayout as? VerticalContentOffsetPreservingLayout
        layout?.isInsertingCellsToTop = origin.y < collectionView.contentOffset.y

//        // Invalidation Logic
        let context = UICollectionViewFlowLayoutInvalidationContext()
        context.invalidateFlowLayoutDelegateMetrics = true
        context.invalidateFlowLayoutAttributes = true
        collectionView.collectionViewLayout.invalidateLayout(with: context)
        collectionView.layoutIfNeeded()

        DispatchQueue.main.async {
            if self.model.slider.isScrubbing {
                self.calculateCurrentChapterScrollRange()
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//    https://stackoverflow.com/a/63500984
//        cache = [:]
//        coordinator.animate(alongsideTransition: { _ in
        ////            self.collectionView.collectionViewLayout.invalidateLayout()
        ////            self.collectionView.layoutIfNeeded()
//
//        }, completion: nil)
        super.viewWillTransition(to: size, with: coordinator)
    }
}

// MARK: DID Scroll

extension VerticalController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        if scrollView.panGestureRecognizer.translation(in: scrollView.superview).y > 0 {
//            lastScrollDirection = .up
//        } else {
//            lastScrollDirection = .down
//        }
        isScrolling = true
        onUserDidScroll(to: scrollView.contentOffset.y)
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing, model.menuControl.menu {
            model.menuControl.hideMenu()
        }
    }

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: currentPoint) else {
            return
        }

        let section = model.sections[path.section]

        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minY
            }
        }

        // Get Max
        if let maxIndex = section.lastIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
            if let attributes = attributes {
                sectionMaxOffset = attributes.frame.maxY - collectionView.frame.height
            }
        }
        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }
}

// MARK: Did Stop Scrolling

extension VerticalController {
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
        model.slider.setCurrent(collectionView.contentOffset.y)
        isScrolling = false
        // Handle Load Prev
        if collectionView.contentOffset.y <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }

        // Calculate Current offset for active path
        let attributes = collectionView.layoutAttributesForItem(at: path)
        if let attributes = attributes {
            let pageOffset = attributes.frame.minY
            let currentOffset = collectionView.contentOffset.y
            model.activeChapter.requestedPageOffset = currentOffset - pageOffset
        }

        model.didScrollTo(path: path)
    }
}

// MARK: Context Menu Delegate

extension VerticalController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration?
    {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)

        // Validate Is Image
        guard let indexPath = indexPath, model.sections[indexPath.section][indexPath.item] is ReaderView.Page else {
            return nil
        }

        // Get Image
        guard let image = (interaction.view as? UIImageView)?.image else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in

            // Image Actiosn menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
            }

            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }

            let photoMenu = UIMenu(title: "Image", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            // Toggle Bookmark
            let chapter = self.model.activeChapter.chapter
            let page = indexPath.item + 1

            var menu = UIMenu(title: "", children: [photoMenu])

            if chapter.chapterType != .EXTERNAL {
                return menu
            }
            // Bookmark Actions
            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter, page: page)
            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"

            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
                DataManager.shared.toggleBookmark(chapter: chapter, page: page)
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
            return menu
        })
    }
}

// MARK: CollectionVeiw Prefetching

extension VerticalController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { path -> URL? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderView.Page, let url = page.hostedURL, model.activeChapter.chapter.chapterType != .LOCAL else {
                return nil
            }

            return URL(string: url)
        }
        prefetcher = ImagePrefetcher(urls: urls)
        prefetcher?.start()
    }

    func collectionView(_: UICollectionView, cancelPrefetchingForItemsAt _: [IndexPath]) {
        prefetcher?.stop()
    }
}

// MARK: Zooming

extension VerticalController: ZoomingViewController, ZoomableHostDelegate, ZoomHandlerDelegate {
    func cellTappedAt(point: CGPoint, frame: CGRect, path: IndexPath) {
        guard let cell = collectionView.cellForItem(at: path) as? ImageCell else {
            return
        }
        selectedIndexPath = path
        let page = VerticalZoomableView()
        page.image = cell.imageView.image
        page.location = point
        page.rect = frame
        page.hostDelegate = self
        model.IN_ZOOM_VIEW = true

        navigationController?.pushViewController(page, animated: true)
    }

    func zoomingBackgroundView(for _: ZoomTransitioningDelegate) -> UIView? {
        return nil
    }

    func zoomingImageView(for _: ZoomTransitioningDelegate) -> UIImageView? {
        guard let indexPath = selectedIndexPath, let cell = collectionView.cellForItem(at: indexPath) as? ImageCell else {
            return nil
        }

        return cell.imageView
    }
}

extension UICollectionView {
    var widestCellWidth: CGFloat {
        let insets = contentInset.left + contentInset.right
        return bounds.width - insets
    }
}
