//
//  DoublePaged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-04.
//

import Combine
import Kingfisher
import SwiftUI
import UIKit

extension DoublePagedViewer {
    final class Controller: UICollectionViewController {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: collectionView.currentPoint)
        }

        var chapterStacksCache: [Int: [StackedPage]] = [:]
        var forcedSingles: [ReaderView.Page] = []

        deinit {
            print("DoublePagedController Deallocated")
        }
    }
}

private typealias Controller = DoublePagedViewer.Controller
private typealias ImageCell = PagedViewer.ImageCell
private typealias StackedImageCell = DoublePagedViewer.StackedImageCell

// MARK: View Setup

extension Controller {
    override func viewDidLoad() {
        super.viewDidLoad()
        setCollectionView()
        registerCells()
        listen()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transformView()
        guard let rChapter = model.readerChapterList.first else {
            return
        }
        let requestedIndex = rChapter.requestedPageIndex
        rChapter.requestedPageOffset = nil
        let openingIndex = getStackedPages(for: 0)
            .firstIndex(where: { $0.pages.contains(where: { ($0 as? ReaderView.Page)?.index == requestedIndex }) }) ?? 0
        collectionView.scrollToItem(at: .init(item: openingIndex, section: 0), at: .centeredHorizontally, animated: false)
        calculateCurrentChapterScrollRange()
        collectionView.isHidden = false
    }

    func registerCells() {
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
        collectionView.register(ReaderView.TransitionCell.self, forCellWithReuseIdentifier: ReaderView.TransitionCell.identifier)
        collectionView.register(StackedImageCell.self, forCellWithReuseIdentifier: StackedImageCell.identifier)
    }

    func setCollectionView() {
        collectionView.prefetchDataSource = self
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        collectionView.isPrefetchingEnabled = true
        collectionView.isPagingEnabled = true
        collectionView.scrollsToTop = false
        collectionView.isHidden = true
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }

    func getLayout() -> UICollectionViewLayout {
        let layout = HorizontalContentSizePreservingFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
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

// MARK: Helpers

extension Controller {
    func transformView() {
        if Preferences.standard.readingLeftToRight {
            collectionView.transform = .identity
        } else {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }
}

// MARK: Update To Chapters Requested Index

extension Controller {
    func moveToRequestedIndex() {}
}

// MARK: Generate Double Paged

extension Controller {
    struct StackedPage: Hashable {
        var pages: [AnyHashable]
        var indices: [Int]
        var locked: Bool
    }

    func getStackedPages(for section: Int) -> [StackedPage] {
        if let pages = chapterStacksCache[section] {
            return pages
        }
        return generatePages(for: section)
    }

    @discardableResult func generatePages(for section: Int) -> [StackedPage] {
        var stacks = [StackedPage]()

        let pages = model.sections[section]
        for (index, page) in zip(pages.indices, pages) {
            // First Page is always Single
            if index == 0 || page is ReaderView.Transition || forcedSingles.contains(where: { (page as? ReaderView.Page) == $0 }) || (page as? ReaderView.Page)?.index == 0 {
                stacks.append(.init(pages: [page], indices: [index], locked: true))
                continue
            }
            if stacks.last != nil, stacks.last!.pages.count < 2, !stacks.last!.locked {
                let stackIndex = stacks.endIndex - 1
                stacks[stackIndex].pages.append(page)
                stacks[stackIndex].indices.append(index)
                stacks[stackIndex].locked = true
            } else {
                stacks.append(.init(pages: [page], indices: [index], locked: false))
            }
        }
        chapterStacksCache[section] = stacks
        return stacks
    }

    func getStack(at path: IndexPath) -> StackedPage {
        return getStackedPages(for: path.section)[path.item]
    }

    func getLastIndex(at path: IndexPath) -> Int {
        let stack = getStack(at: path)
        return stack.indices.max() ?? 0
    }
}

// MARK: CollectionView Sections

extension Controller {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return getStackedPages(for: section).count
    }
}

// MARK: Cell Sizing

extension Controller: UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return UIScreen.main.bounds.size
    }
}

// MARK: Cell For Item At

extension Controller {
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell = UICollectionViewCell()
        handleChapterPreload(at: indexPath)
        let stackedPage = getStack(at: indexPath)

        if stackedPage.indices.count > 1 {
            // Double Paged Cell
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: StackedImageCell.identifier, for: indexPath) as! StackedImageCell
            (cell as! StackedImageCell).configure(for: stackedPage)

            for pageView in (cell as! StackedImageCell).stackView?.arrangedSubviews ?? [] {
                guard let pageView = pageView as? DoublePagedViewer.DImageView else {
                    continue
                }

                pageView.lm = self

                if UserDefaults.standard.bool(forKey: STTKeys.ImageInteractions) {
                    pageView.imageView.addInteraction(UIContextMenuInteraction(delegate: self))
                }
                //
                if !model.slider.isScrubbing {
                    pageView.setImage()
                }
            }
        } else {
            // Single Paged Cell
            let page = stackedPage.pages.first!

            if let page = page as? ReaderView.Page {
                // Is Image Page
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell
                (cell as! ImageCell).initializePage(page: page)
                //            // Enable Interactions
                if UserDefaults.standard.bool(forKey: STTKeys.ImageInteractions) {
                    (cell as! ImageCell).pageView?.imageView.addInteraction(UIContextMenuInteraction(delegate: self))
                }
                //
                if !model.slider.isScrubbing {
                    (cell as! ImageCell).pageView?.setImage()
                }

            } else {
                // Is Transition Page
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderView.TransitionCell.identifier, for: indexPath) as! ReaderView.TransitionCell
                (cell as! ReaderView.TransitionCell).configure(page as! ReaderView.Transition)
            }
        }

        cell.backgroundColor = .clear

        return cell
    }
}

// MARK: Context Menu Delegate

extension Controller: UIContextMenuInteractionDelegate {
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

            if chapter.chapterType == .LOCAL {
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

// MARK: DoublePaged Layout Manager

extension Controller: DoublePagedLayoutManager {
    func resizeToSingle(page: ReaderView.Page) {
        // Already Resized
        if forcedSingles.contains(where: { $0 == page }) {
            return
        }

        forcedSingles.append(page)

        guard let index = model.readerChapterList.firstIndex(where: { $0.chapter._id == page.chapterId }) else {
            return
        }

        generatePages(for: index)
        DispatchQueue.main.async { [unowned self] in
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            collectionView.performBatchUpdates({
                self.collectionView.reloadSections([index])

            }) { [unowned self] finished in
                if finished {
//                    if let currentPath = currentPath {
//                        collectionView.reloadItems(at: [currentPath])
//                    }
                    CATransaction.commit()
                    self.calculateCurrentChapterScrollRange()
                }
            }
        }
    }
}

// MARK: PUB_SUB

extension Controller {
    func listen() {
        // MARK: LTR & RTL Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.readingLeftToRight == $0 }
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.transformView()
                    self?.collectionView.collectionViewLayout.invalidateLayout()
                    self?.calculateCurrentChapterScrollRange()
                }
            }
            .store(in: &subscriptions)

        // MARK: Reload Publisher

        model.reloadPublisher.sink { [weak self] in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
                self?.collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Slider Publisher

        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: slider.current, y: 0)

                if let path = collectionView.indexPathForItem(at: position), let item = model.sections[path.section][getLastIndex(at: path)] as? ReaderView.Page {
                    model.scrubbingPageNumber = item.index + 1
                }

                collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: DID END SCRUBBING PUBLISHER

        model.scrubEndPublisher.sink { [unowned self] in
            guard let currentPath = currentPath else {
                return
            }
            collectionView.scrollToItem(at: currentPath, at: .centeredHorizontally, animated: true)
        }
        .store(in: &subscriptions)

        // MARK: DID PREFERENCE CHANGE PUBLISHER

        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.forceTransitions ||
                    changedKeyPath == \Preferences.imageInteractions
            }
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.collectionView.reloadData()
                }
            }
            .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in
            let rtl = Preferences.standard.readingLeftToRight

            var isPreviousTap = action == .LEFT
            if !rtl { isPreviousTap.toggle() }

            let width = collectionView.frame.width
            let offset = isPreviousTap ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width

            let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

            if let path = path {
                collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Insert Publisher

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in
                let topInsertion = section == 0 && model.sections.count != 0
//                 Next Chapter Logic
                if topInsertion {
                    moveStackCache()
                }
                let data = getStackedPages(for: section)
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? HorizontalContentSizePreservingFlowLayout

                layout?.isInsertingCellsToTop = topInsertion

                CATransaction.begin()
                CATransaction.setDisableActions(true)

                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    print(set.count)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)
    }

    func moveStackCache() {
        let keys = chapterStacksCache.keys.reversed()

        for key in keys {
            chapterStacksCache[key + 1] = chapterStacksCache[key]
        }
        chapterStacksCache.removeValue(forKey: 0)
    }
}

// MARK: SCROLLABLE OFFSET

extension Controller {
    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: collectionView.currentPoint) else {
            return
        }

        let stacks = getStackedPages(for: path.section)

        // Get Min
        if let minIndex = stacks.firstIndex(where: { model.getObject(atPath: .init(item: $0.indices.min() ?? 0, section: path.section)) is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }

        // Get Max
        if let maxIndex = stacks.lastIndex(where: { model.getObject(atPath: .init(item: $0.indices.max() ?? 0, section: path.section)) is ReaderView.Page }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
            if let attributes = attributes {
                sectionMaxOffset = attributes.frame.maxX - collectionView.frame.width
            }
        }

        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }
}

// MARK: DID SCROLL

extension Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.x)
    }

    func onUserDidScroll(to offset: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing {
            model.menuControl.hideMenu()
            model.slider.setCurrent(offset)
        }
    }
}

// MARK: DID STOP SCROLL

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
        // Handle Load Prev
        if collectionView.contentOffset.x <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }
        model.activeChapter.requestedPageOffset = nil
        let lastStackIndex = getLastIndex(at: path)
        model.didScrollTo(path: .init(item: lastStackIndex, section: path.section))
        model.scrubbingPageNumber = nil
    }
}

// MARK: Handle Chapter Preload

extension Controller {
    func handleChapterPreload(at path: IndexPath) {
        guard let currentPath = currentPath, currentPath.section == path.section else {
            return
        }
        let currentItem = getLastIndex(at: currentPath)
        let pathItem = getLastIndex(at: path)
        if currentItem < pathItem {
            let preloadNext = model.sections[path.section].count - pathItem + 1 < 5
            if preloadNext, model.readerChapterList.get(index: path.section + 1) == nil {
                model.loadNextChapter()
            }
        }
    }
}

// MARK: Will Transition To

extension Controller {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }
}

// MARK: CollectionView Will & Did

extension Controller {
    override func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt _: IndexPath) {
        if let cell = cell as? ImageCell {
            cell.setImage()
        } else if let cell = cell as? StackedImageCell {
            cell.setImages()
        }
    }

    override func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt _: IndexPath) {
        if let cell = cell as? ImageCell {
            cell.pageView?.imageView.kf.cancelDownloadTask()
            cell.pageView?.downloadTask?.cancel()
        } else if let cell = cell as? StackedImageCell {
            cell.cancelImages()
        }
    }
}

// MARK: CollectionView Prefetching

extension Controller: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        ImagePrefetcher(urls: getValidUrls(at: indexPaths)).start()
    }

    func collectionView(_: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        ImagePrefetcher(urls: getValidUrls(at: indexPaths)).stop()
    }

    func getValidUrls(at paths: [IndexPath]) -> [URL] {
        let paths = paths.flatMap { path in
            getStack(at: path).indices.map { item in
                IndexPath(item: item, section: path.section)
            }
        }

        let urls = paths.compactMap { path -> URL? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderView.Page, let url = page.hostedURL, !page.isLocal else {
                return nil
            }

            return URL(string: url)
        }

        return urls
    }
}
