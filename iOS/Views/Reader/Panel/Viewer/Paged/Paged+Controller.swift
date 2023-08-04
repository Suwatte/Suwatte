//
//  Paged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-20.
//

import Combine
import Nuke
import UIKit

extension UICollectionView {
    var currentPoint: CGPoint {
        .init(x: contentOffset.x + frame.midX, y: contentOffset.y + frame.midY)
    }
}

extension PagedViewer {
    final class PagedController: UICollectionViewController {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: collectionView.currentPoint)
        }

        var isScrolling: Bool = false
        var enableInteractions: Bool = Preferences.standard.imageInteractions
        var lastPathBeforeRotation: IndexPath?
        var lastViewedSection = 0
        private let prefetcher = ImagePrefetcher()
        private var didTriggerBackTick = false
    }
}

private typealias PagedController = PagedViewer.PagedController

// MARK: View Setup

private typealias ImageCell = PagedViewer.ImageCell

extension PagedController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setCollectionView()
        registerCells()
        addModelSubscribers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        transformView()
        guard let rChapter = model.readerChapterList.first else {
            return
        }

        if model.sections.isEmpty {
            collectionView.isHidden = false
            return
        }
        let requestedIndex = rChapter.requestedPageIndex
        rChapter.requestedPageOffset = nil
        let openingIndex = model.sections.first?.firstIndex(where: { ($0 as? ReaderPage)?.page.index == requestedIndex }) ?? requestedIndex
        let path: IndexPath = .init(item: openingIndex, section: 0)
        collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: false)
        let point = collectionView.layoutAttributesForItem(at: path)?.frame.minX ?? 0
        DispatchQueue.main.async {
            self.model.slider.setCurrent(point)
            self.calculateCurrentChapterScrollRange()
        }
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

    func getLayout() -> UICollectionViewLayout {
        let layout = HorizontalContentSizePreservingFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
        layout.estimatedItemSize = .zero
        return layout
    }
}

// MARK: Subscriptions

extension PagedController {
    func addModelSubscribers() {
        // MARK: Reload

        model.reloadPublisher.sink { [unowned self] in
            DispatchQueue.main.async {
                collectionView.reloadData()
                collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Insert

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in
                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? HorizontalContentSizePreservingFlowLayout
                layout?.isInsertingCellsToTop = section == 0 && model.sections.count != 0
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    guard finished else { return }
                    CATransaction.commit()
                    Task {
                        calculateCurrentChapterScrollRange()
                    }
                }
            }

        }.store(in: &subscriptions)

        // MARK: Slider

        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: slider.current, y: 0)

                if let path = collectionView.indexPathForItem(at: position), let item = model.sections[path.section][path.item] as? ReaderPage {
                    model.scrubbingPageNumber = item.page.index + 1
                }

                collectionView.setContentOffset(position, animated: false)
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

        // MARK: Did End Scrubbing

        model.scrubEndPublisher.sink { [weak self] in
            guard let currentPath = self?.currentPath else {
                return
            }
            self?.collectionView.scrollToItem(at: currentPath, at: .centeredHorizontally, animated: true)
        }
        .store(in: &subscriptions)

        // MARK: Preference Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.imageInteractions
            }
            .sink { [unowned self] _ in
                DispatchQueue.main.async {
                    collectionView.reloadData()
                }
            }
            .store(in: &subscriptions)
//
//        // MARK: LTR & RTL Publisher
//
        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.readingLeftToRight == $0 }
            .sink { [unowned self] _ in
                transformView()
                DispatchQueue.main.async {
                    collectionView.collectionViewLayout.invalidateLayout()
                    calculateCurrentChapterScrollRange()
                }
            }
            .store(in: &subscriptions)
//

//
//        // MARK: User Default
        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.imageInteractions == $0 }
            .sink { [unowned self] _ in
                enableInteractions = Preferences.standard.imageInteractions
            }
            .store(in: &subscriptions)
    }

    func transformView() {
        if Preferences.standard.readingLeftToRight {
            collectionView.transform = .identity
        } else {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }
}

// MARK: CollectionView Sections

extension PagedController {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        model.sections[section].count
    }
}

// MARK: Cell For Item At

extension PagedController {
    override func viewDidLayoutSubviews() {
        if !isScrolling {
            super.viewDidLayoutSubviews()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Cell Logic
        let data = model.getObject(atPath: indexPath)
        if let data = data as? ReaderPage {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell // Dequeue
            cell.set(page: data, delegate: self) // SetUp
            cell.setImage() // Set Image
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderView.TransitionCell.identifier, for: indexPath) as! ReaderView.TransitionCell
        cell.configure(data as! ReaderView.Transition)
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: CollectionView Will & Did

extension PagedController {
    override func collectionView(_: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        handleChapterPreload(at: indexPath)
    }

    override func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt _: IndexPath) {
        guard let cell = cell as? ImageCell else {
            return
        }
        cell.cancelTasks()
    }
}

// MARK: Chapter Preloading

extension PagedController {
    func handleChapterPreload(at path: IndexPath) {
        guard let currentPath = currentPath, currentPath.section == path.section else {
            return
        }

        if currentPath.item < path.item {
            let preloadNext = model.sections[path.section].count - path.item + 1 < 5
            if preloadNext, model.readerChapterList.get(index: path.section + 1) == nil {
                Task { [weak self] in
                    await self?.model.loadNextChapter()
                }
            }
        }
    }
}

// MARK: Cell Sizing

extension PagedController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}

// MARK: DID Scroll

import SwiftUI
extension PagedController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.x)
        isScrolling = true
    }

    func onUserDidScroll(to pos: CGFloat) {
        // Update Offset
        guard !model.slider.isScrubbing else { return }

        if pos < 0 {
            didTriggerBackTick = true
            return
        }
        Task { @MainActor in
            model.slider.setCurrent(pos)
        }
    }

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: collectionView.currentPoint) else {
            return
        }

        let section = model.sections[path.section]
        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderPage }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }

        // Get Max
        let maxIndex = max(section.endIndex - 2, 0)
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            sectionMaxOffset = attributes.frame.minX
        }
        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }
}

// MARK: Did Stop Scrolling

extension PagedController {
    override func scrollViewDidEndDecelerating(_: UIScrollView) {
        Task {
            onScrollStop()
            lastPathBeforeRotation = currentPath
        }
    }

    override func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        Task {
            onScrollStop()
        }
    }

    override func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        Task {
            onScrollStop()
        }
    }

    func onScrollStop() {
        isScrolling = false
        model.menuControl.hideMenu()

        // Handle Load Prev
        if didTriggerBackTick {
            model.loadPreviousChapter()
            didTriggerBackTick = false
        }

        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }

        if path.section != lastViewedSection {
            STTHelpers.triggerHaptic()
            lastViewedSection = path.section
        }
        model.activeChapter.requestedPageOffset = nil
        Task {
            model.didScrollTo(path: path)
        }
        model.scrubbingPageNumber = nil
    }
}

// MARK: Context Menu Delegate

extension PagedController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration?
    {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)

        // Validate Is Image
        guard let indexPath = indexPath, let page = model.sections[indexPath.section][indexPath.item] as? ReaderPage else {
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
                ToastManager.shared.info("Panel Saved!")
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

            var menu = UIMenu(title: "", children: [photoMenu])

            if chapter.chapterType != .EXTERNAL {
                return menu
            }
            // Bookmark Actions
            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter.toStored(), page: page.page.index)
            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"

            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
                DataManager.shared.toggleBookmark(chapter: chapter.toStored(), page: page.page.index)
                ToastManager.shared.info("Bookmark \(isBookmarked ? "Removed" : "Added")!")
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
            return menu
        })
    }
}

// MARK: CollectionVeiw Prefetching

extension PagedController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let pages = indexPaths.compactMap { path -> ReaderView.Page? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderPage else {
                return nil
            }
            return page.page
        }
        Task { [weak self] in
            let requests = await withTaskGroup(of: ImageRequest?.self) { group in

                for page in pages {
                    group.addTask {
                        try? await page.getImageRequest()
                    }
                }

                var out = [ImageRequest]()
                for await result in group {
                    if let result {
                        out.append(result)
                    }
                }
                return out
            }
            self?.prefetcher.startPrefetching(with: requests)
        }
    }

    func collectionView(_: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let pages = indexPaths.compactMap { path -> ReaderView.Page? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderPage else {
                return nil
            }
            return page.page
        }

        Task { [weak self] in
            let requests = await withTaskGroup(of: ImageRequest?.self) { group in

                for page in pages {
                    group.addTask {
                        try? await page.getImageRequest()
                    }
                }

                var out = [ImageRequest]()
                for await result in group {
                    if let result {
                        out.append(result)
                    }
                }
                return out
            }
            self?.prefetcher.stopPrefetching(with: requests)
        }
    }
}

extension PagedController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
        super.viewWillTransition(to: size, with: coordinator)
    }
}
