//
//  Vertical+ASController.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-04.
//

import AsyncDisplayKit
import Combine
import Kingfisher
import SwiftUI
import UIKit

extension VerticalViewer {
    class Controller: ASDKViewController<ASCollectionNode> {
        internal let model: ReaderView.ViewModel
        private let zoomTransitionDelegate = ZoomTransitioningDelegate()
        var subscriptions = Set<AnyCancellable>()
        var selectedIndexPath: IndexPath!
        var initialOffset: (Int, CGFloat?)?
        var timer: Timer?
        var lastViewedSection = 0

        // MARK: Init

        init(model: ReaderView.ViewModel) {
            let layout = VerticalContentOffsetPreservingLayout()
            let node = ASCollectionNode(collectionViewLayout: layout)
            self.model = model
            super.init(node: node)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: View Did Load

        override func viewDidLoad() {
            collectionNode.delegate = self
            collectionNode.dataSource = self
            collectionNode.shouldAnimateSizeChanges = false
            collectionNode.backgroundColor = .clear
            collectionNode.insetsLayoutMarginsFromSafeArea = false
            collectionNode.alpha = 0
            collectionNode.automaticallyManagesSubnodes = true
            listen()
            navigationController?.delegate = zoomTransitionDelegate
            navigationController?.isNavigationBarHidden = true
            navigationController?.isToolbarHidden = true

            collectionNode.isPagingEnabled = false
            collectionNode.showsVerticalScrollIndicator = false
            collectionNode.showsHorizontalScrollIndicator = false
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)

            let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTapGR.numberOfTapsRequired = 2
            tapGR.require(toFail: doubleTapGR)
            collectionNode.view.addGestureRecognizer(doubleTapGR)
            collectionNode.view.addGestureRecognizer(tapGR)
            collectionNode.view.contentInsetAdjustmentBehavior = .never
            collectionNode.view.scrollsToTop = false
            collectionNode.leadingScreensForBatching = 2

            Task { @MainActor in
                model.slider.setRange(0, 1)
            }
        }

        @objc func appMovedToBackground() {
            cancelAutoScroll()
        }

        // MARK: View DidAppear

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            if model.IN_ZOOM_VIEW {
                model.IN_ZOOM_VIEW = false
                return
            }

            guard let rChapter = model.readerChapterList.first else {
                return
            }
            let requestedIndex = rChapter.requestedPageIndex
            let openingIndex = model
                .sections[0]
                .firstIndex(where: { ($0 as? ReaderPage)?.page.index == requestedIndex }) ?? requestedIndex
            let path: IndexPath = .init(item: openingIndex, section: 0)
            collectionNode.scrollToItem(at: path, at: .top, animated: false)

            // TODO: Last Offset
            if let lastOffset = rChapter.requestedPageOffset {
                collectionNode.contentOffset.y += lastOffset
            }

            updateSliderOffset()

            UIView.animate(withDuration: 0.2,
                           delay: 0.0,
                           options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.collectionNode.alpha = 1
            }
        }

        var collectionNode: ASCollectionNode {
            return node
        }

        var contentSize: CGSize {
            collectionNode.collectionViewLayout.collectionViewContentSize
        }
    }
}

private typealias Controller = VerticalViewer.Controller

// MARK: Collection DataSource

extension Controller: ASCollectionDataSource {
    func numberOfSections(in _: ASCollectionNode) -> Int {
        return model.sections.count
    }

    func collectionNode(_: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        return model.sections[section].count
    }
}

// MARK: Collection Delegate

extension Controller: ASCollectionDelegate {
    func collectionNode(_: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let data = model.getObject(atPath: indexPath)

        if let data = data as? ReaderPage {
            return {
                let node = Controller.ImageNode(page: data.page)
                node.delegate = self
                if let target = self.initialOffset, indexPath.section == 0, indexPath.item == target.0, let offset = target.1 {
                    node.savedOffset = offset
                }
                return node
            }
        } else if let data = data as? ReaderView.Transition {
            return {
                let node = TransitionNode(transition: data)
                node.delegate = self
                return node
            }
        } else {
            return {
                EmptyNode()
            }
        }
    }
}

private class EmptyNode: ASCellNode {}

extension VerticalViewer.Controller {
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        cancelAutoScroll()
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: navigationController?.view)
        Task {
            model.handleNavigation(location)
        }
    }

    @objc func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }

    func shouldBatchFetch(for _: ASCollectionNode) -> Bool {
        guard let currentPath else {
            return false
        }
        let index = currentPath.section
        let item = currentPath.item + 1
        let count = model.sections[index].count
        return model.readerChapterList.get(index: item) == nil && count - item <= 3
    }

    func collectionNode(_: ASCollectionNode, willBeginBatchFetchWith context: ASBatchContext) {
        model.loadNextChapter()
        context.completeBatchFetching(true)
    }
}
