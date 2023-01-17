//
//  VerticalPaged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-22.
//

import Combine
import Foundation
import Kingfisher
import UIKit

extension VerticalPager {
    final class Controller: UICollectionViewController, PagerDelegate {
        var model: ReaderView.ViewModel!
        var subscriptions = Set<AnyCancellable>()
        var currentPath: IndexPath? {
            collectionView.indexPathForItem(at: collectionView.currentPoint)
        }

        var isScrolling: Bool = false

        var enableInteractions: Bool = Preferences.standard.imageInteractions

        deinit {
            Logger.shared.debug("Vertical Pager Controller Deallocated")
        }
    }
}

private typealias Controller = VerticalPager.Controller
private typealias ImageCell = PagedViewer.ImageCell

// MARK: DataSource

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
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return UIScreen.main.bounds.size
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
        collectionView.scrollToItem(at: path, at: .centeredVertically, animated: false)
        let point = collectionView.layoutAttributesForItem(at: path)?.frame.midY ?? 0
        model.slider.setCurrent(point)
        DispatchQueue.main.async {
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
        collectionView.contentInsetAdjustmentBehavior = .never
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
        let layout = VerticalContentOffsetPreservingLayout()
        layout.scrollDirection = .vertical
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
        let urls = indexPaths.compactMap { path -> URL? in
            guard let page = self.model.sections[path.section][path.item] as? ReaderPage, let url = page.page.hostedURL, !page.page.isLocal else {
                return nil
            }

            return URL(string: url)
        }
        ImagePrefetcher(urls: urls).start()
    }
}

// MARK: CollectionView Will & Did

extension Controller {
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

extension Controller {
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

// MARK: Cell For Item At

extension Controller {
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Cell Logic
        let data = model.getObject(atPath: indexPath)

        if let data = data as? ReaderPage {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell
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

// MARK: Layout & Transitions

extension Controller {
    override func viewDidLayoutSubviews() {
        if !isScrolling {
            super.viewDidLayoutSubviews()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastPath = currentPath
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
        }, completion: { _ in
            guard let lastPath = lastPath, let attributes = self.collectionView.layoutAttributesForItem(at: lastPath) else {
                return
            }
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(.init(x: 0, y: attributes.frame.origin.y), animated: true)
            }
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
}
