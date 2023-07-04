//
//  DoublePaged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-15.
//

import Combine
import Foundation
import Nuke
import UIKit

extension DoublePagedViewer {
    final class Controller: UICollectionViewController {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: collectionView.currentPoint)
        }

        var isScrolling: Bool = false
        var cache: [Int: [PageGroup]] = [:]
        var pendingUpdates = false
        var lastViewedSection = 0
        private let prefetcher = ImagePrefetcher()
    }
}

private typealias Controller = DoublePagedViewer.Controller
private typealias DoublePageCell = DoublePagedViewer.ImageCell
private typealias SinglePageCell = PagedViewer.ImageCell

// MARK: DataSource

extension Controller {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        getStack(for: section).count
    }
}

// MARK: Cell Sizing

extension Controller: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}

// MARK: Set Up

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
        model.slider.setRange(0, 1)
        guard let rChapter = model.readerChapterList.first else {
            return
        }

        if model.sections.isEmpty {
            collectionView.isHidden = false
            return
        }
        let requestedIndex = rChapter.requestedPageIndex
        rChapter.requestedPageOffset = nil
        let pageIndex = model
            .sections
            .first?
            .firstIndex(where: { ($0 as? ReaderPage)?.page.index == requestedIndex }) ?? rChapter.requestedPageIndex
        let page = model
            .sections[0]
            .get(index: pageIndex)
        let open = getStack(for: 0)
            .firstIndex(where: { $0.primary === page || $0.secondary === page }) ?? 0
        collectionView.scrollToItem(at: .init(item: open, section: 0), at: .centeredHorizontally, animated: false)
        updateSliderOffset()
        collectionView.isHidden = false
        collectionView.backgroundColor = .clear
    }

    func registerCells() {
        collectionView.register(DoublePageCell.self, forCellWithReuseIdentifier: DoublePageCell.identifier)
        collectionView.register(SinglePageCell.self, forCellWithReuseIdentifier: SinglePageCell.identifier)

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

    func transformView() {
        if Preferences.standard.readingLeftToRight {
            collectionView.transform = .identity
        } else {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
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

// MARK: Prefetching

extension Controller: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let pages = indexPaths.compactMap { path -> ReaderView.Page? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderPage else {
                return nil
            }
            return page.page
        }
        Task.detached { [weak self] in
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

        Task.detached { [weak self] in
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

// MARK: CollectionView Will & Did

extension Controller {
    override func collectionView(_: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        handleChapterPreload(at: indexPath)
    }

    override func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt _: IndexPath) {
        if let cell = cell as? DoublePageCell {
            cell.cancelTasks()
        } else if let cell = cell as? SinglePageCell {
            cell.cancelTasks()
        }
    }
}

// MARK: Chapter Preloading

extension Controller {
    func handleChapterPreload(at path: IndexPath) {
        guard let currentPath = currentPath, currentPath.section == path.section else {
            return
        }

        if currentPath.item < path.item {
            let preloadNext = getStack(for: path.section).count - path.item < 2
            if preloadNext, model.readerChapterList.get(index: path.section + 1) == nil {
                model.loadNextChapter()
            }
        }
    }
}

// MARK: Cell For Item At

extension Controller {
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Cell Logic
        let data = cache[indexPath.section]?[indexPath.item]

        guard let data else { fatalError("Stack Not Defined") }
        if let transition = data.primary as? ReaderView.Transition {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReaderView.TransitionCell.identifier, for: indexPath) as! ReaderView.TransitionCell
            cell.configure(transition)
            cell.backgroundColor = .clear
            return cell
        }

        let target = data.primary as? ReaderPage
        let secondary = data.secondary as? ReaderPage
        guard let target else { fatalError("Target Not ReaderPage") }
        if let secondary {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DoublePageCell.identifier, for: indexPath) as! DoublePageCell
            cell.set(primary: target, secondary: secondary, delegate: self) // SetUp
            cell.setImage() // Set Image
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SinglePageCell.identifier, for: indexPath) as! SinglePageCell
        cell.set(page: target, delegate: self)
        cell.setImage()
        return cell
    }
}

// MARK: Layout & Transitions

extension Controller {
    override func viewDidLayoutSubviews() {
        if !isScrolling {
            super.viewDidLayoutSubviews()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
        super.viewWillTransition(to: size, with: coordinator)
    }
}

extension Controller {
    class PageGroup {
        var primary: AnyObject
        var secondary: AnyObject?
        init(primary: AnyObject, secondary: AnyObject? = nil) {
            self.primary = primary
            self.secondary = secondary
        }
    }

    @discardableResult func generatePages(for section: Int) -> [PageGroup] {
        guard let pages = model.sections.get(index: section) else { return [] }
        var stack: [PageGroup] = []
        for page in pages {
            let last = stack.last

            // Last Stack Has Free Postion
            if let last, last.secondary == nil {
                // Current Item Is Transition
                if page is ReaderView.Transition {
                    stack.append(.init(primary: page))
                    continue
                }

                // - Item Is A ReaderPage
                // Last Stack Cannot Have A Secondary Page, Append New Page
                if last.primary is ReaderView.Transition || ((last.primary as? ReaderPage)?.isFullPage ?? false) {
                    stack.append(.init(primary: page))
                    continue
                }

                // Last Stack Can Have Secondary
                last.secondary = page
                continue
            }
            // Last Stack is Full, Create New Stack
            stack.append(.init(primary: page))
        }
        cache[section] = stack
        return stack
    }

    func didIsolatePage(maintain page: ReaderPage, note secondary: ReaderPage?) {
        guard let section = model.chapterSectionCache[page.page.chapterId] else {
            return
        }
        if page.didIsolate || secondary?.didIsolate ?? false {
            return
        }
        page.didIsolate = true

        generatePages(for: section)
        pendingUpdates = true
    }

    func applyPendingUpdates() {
        guard pendingUpdates, let currentPath else { return }

        DispatchQueue.main.async {
            self.collectionView.performBatchUpdates({
                self.collectionView.reloadSections([currentPath.section])
            }) { [weak self] _ in
                self?.pendingUpdates = false
            }
        }
        // TODO: Bug when navigating backward, Jumps Page Being navigated to in favour of the new page at that index
    }

    func getStack(for section: Int) -> [PageGroup] {
        if let pages = cache[section] {
            return pages
        }
        return generatePages(for: section)
    }
}