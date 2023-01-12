//
//  Novel+Paged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-30.
//

import Combine
import Foundation
import UIKit

extension NovelReaderView.PagedViewer {
    class Controller: UICollectionViewController {
        var model: NovelReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()

        override func viewDidLoad() {
            super.viewDidLoad()
            setCollectionView()
            collectionView.register(ContentCell.self, forCellWithReuseIdentifier: ContentCell.identifier)
            listen()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let rChapter = model.readerChapterList.first else {
                return
            }
            let requestedIndex = rChapter.requestedPageIndex
            rChapter.requestedPageOffset = nil
            var openingIndex = min(requestedIndex, model.getPageCount())
            openingIndex = max(requestedIndex, 0)
            collectionView.scrollToItem(at: .init(item: openingIndex, section: 0), at: .centeredHorizontally, animated: false)
            calculateCurrentChapterScrollRange()
            Task { @MainActor in
                model.currentSectionPageNumber = openingIndex + 1
            }
            collectionView.isHidden = false
        }
    }
}

private typealias Controller = NovelReaderView.PagedViewer.Controller

// MARK: Layout

extension Controller {
    func setCollectionView() {
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        collectionView.isPagingEnabled = true
        collectionView.scrollsToTop = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.isHidden = true
    }

    func getLayout() -> UICollectionViewLayout {
        let layout = NovelOffsetPreservingLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
        return layout
    }
}

// MARK: CollectionView Sections

extension Controller {
    override func numberOfSections(in _: UICollectionView) -> Int {
        model.sections.count
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        model.sections[section].count
    }
}

// MARK: Cell Sizing

extension Controller: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.frame.size
    }
}

// Cell
extension Controller {
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        handleChapterPreload(at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ContentCell.identifier, for: indexPath) as! ContentCell
        cell.subviews.forEach { view in
            view.removeFromSuperview()
        }
        let label = model.getPage(at: indexPath).view
        label.frame = view.frame
        cell.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cell.topAnchor),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            label.leftAnchor.constraint(equalTo: cell.leftAnchor),
            label.rightAnchor.constraint(equalTo: cell.rightAnchor),
        ])
        return cell
    }
}

// Pub Sub
extension Controller {
    func listen() {
        model.reloadPublisher.sink {
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.reloadData()
                var pageIndex = 0
                if let requestedIndex = self?.model.activeChapter.requestedPageIndex, requestedIndex != 0 {
                    pageIndex = self?.model.sections.first?.lastIndex(where: { $0.lastPageIndex <= requestedIndex }) ?? 0
                }
                self?.collectionView.scrollToItem(at: .init(item: pageIndex, section: 0), at: .centeredHorizontally, animated: false)
                self?.calculateCurrentChapterScrollRange()
                self?.model.currentSectionPageNumber = pageIndex + 1
            }

        }.store(in: &subscriptions)

        // MARK: Insert

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in

                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? NovelOffsetPreservingLayout
                layout?.isInsertingCellsToTop = section == 0 && model.sections.count != 0

                CATransaction.begin()
                CATransaction.setDisableActions(true)
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

        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: slider.current, y: 0)

                if let path = collectionView.indexPathForItem(at: position) {
                    model.scrubbingPageNumber = path.item + 1
                }

                collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: Did End Scrubbing

        model.scrubEndPublisher.sink { [unowned self] in
            guard let currentPath = currentPath else {
                return
            }
            collectionView.scrollToItem(at: currentPath, at: .centeredHorizontally, animated: true)
        }
        .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in

            let isPreviousTap = action == .LEFT

            let width = collectionView.frame.width
            let offset = isPreviousTap ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width

            let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

            if let path = path {
                collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
            }
        }
        .store(in: &subscriptions)
    }
}

// MARK: Chapter Preload

extension Controller {
    var currentPath: IndexPath? {
        collectionView.indexPathForItem(at: collectionView.currentPoint)
    }

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

// MARK: DID Scroll

import SwiftUI
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

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: collectionView.currentPoint) else {
            return
        }
        let lastIndex = model.sections[path.section].count - 1
        // Get Min
        if let attributes = collectionView.layoutAttributesForItem(at: .init(item: 0, section: path.section)) {
            sectionMinOffset = attributes.frame.minX
        }

        // Get Max
        if let attributes = collectionView.layoutAttributesForItem(at: .init(item: lastIndex, section: path.section)) {
            sectionMaxOffset = attributes.frame.maxX - collectionView.frame.width
        }

        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
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
        model.didScrollTo(path: path)
        model.scrubbingPageNumber = nil
    }
}

// MARK: Will Transition To

extension Controller {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let lastPath = currentPath

        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
        }, completion: { _ in
            guard let lastPath = lastPath, let attributes = self.collectionView.layoutAttributesForItem(at: lastPath) else {
                return
            }
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.init(x: attributes.frame.origin.x, y: 0), animated: true)
            }
        })
    }
}
