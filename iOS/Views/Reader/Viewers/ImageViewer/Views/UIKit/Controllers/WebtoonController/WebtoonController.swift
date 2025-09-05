//
//  WebtoonController.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

@preconcurrency import AsyncDisplayKit
import Combine
import OrderedCollections
import SwiftUI
import UIKit

extension IndexPath {
    var isFirst: Bool {
        section == 0 && (item == 0 || row == 0)
    }
}

class WebtoonController: ASDKViewController<ASCollectionNode> {
    let model: IVViewModel
    var subscriptions = Set<AnyCancellable>()
    var timer: Timer?
    var isZooming = false
    var dataSource = WCDataSource()
    var resumptionPosition: (Int, CGFloat)?
    var preRotationPath: IndexPath?
    var preRotationOffset: CGFloat?
    var lastIndexPath: IndexPath = .init(item: 0, section: 0)
    var currentChapterRange: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
    var didTriggerBackTick = false
    var lastKnownScrollPosition: CGFloat = 0.0
    var lastStoppedScrollPosition: CGFloat = 0.0
    var scrollPositionUpdateThreshold: CGFloat = 30.0
    var currentZoomingIndexPath: IndexPath!
    var hasCompletedInitialLoad = false

    var isReadyToAddOffset = false
    private let zoomTransitionDelegate = ZoomTransitioningDelegate()
    var onPageReadTask: Task<Void, Never>?

    // Computed
    var dataCache: IVDataCache {
        model.dataCache
    }

    var collectionNode: ASCollectionNode {
        return node
    }

    var contentSize: CGSize {
        collectionNode.collectionViewLayout.collectionViewContentSize
    }

    var offset: CGFloat {
        collectionNode.contentOffset.y
    }

    var currentPoint: CGPoint {
        collectionNode.view.currentPoint
    }

    var currentPath: IndexPath? {
        collectionNode.view.pathAtCenterOfScreen
    }

    var pathAtCenterOfScreen: IndexPath? {
        collectionNode.view.pathAtCenterOfScreen
    }

    // Init
    init(model: IVViewModel) {
        let layout = VImageViewerLayout()
        let node = ASCollectionNode(collectionViewLayout: layout)
        self.model = model
        super.init(node: node)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    deinit {
        timer = nil
        NotificationCenter
            .default
            .removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    // Core
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        setNeedsUpdateOfHomeIndicatorAutoHidden()

        if !hasCompletedInitialLoad {
            startup()
            subscribeAll()
            return
        }

        if isZooming {
            isZooming = false
            return
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @objc func appMovedToBackground() {
        cancelAutoScroll()
    }

    func presentNode() {
        UIView.animate(withDuration: 0.2,
                       delay: 0.0,
                       options: [.transitionCrossDissolve, .allowUserInteraction])
        {
            self.collectionNode.alpha = 1
        }
    }

    func clearResumption() {
        resumptionPosition = nil
    }
}

private typealias Controller = WebtoonController

// MARK: - Empty Cell

private class EmptyNode: ASCellNode {}

// MARK: - Setup

extension Controller {
    func setup() {
        collectionNode.delegate = self
        collectionNode.dataSource = self
        collectionNode.shouldAnimateSizeChanges = false
        collectionNode.backgroundColor = .clear
        collectionNode.insetsLayoutMarginsFromSafeArea = false
        collectionNode.alpha = 0
        collectionNode.automaticallyManagesSubnodes = true

        navigationController?.delegate = zoomTransitionDelegate
        navigationController?.isNavigationBarHidden = true
        navigationController?.isToolbarHidden = true

        collectionNode.isPagingEnabled = false
        collectionNode.showsVerticalScrollIndicator = false
        collectionNode.showsHorizontalScrollIndicator = false

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(appMovedToBackground),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)

        addGestures()
        collectionNode.view.contentInsetAdjustmentBehavior = .never
        collectionNode.view.scrollsToTop = false
    }
}

// MARK: Controller

extension Controller: ASCollectionDataSource {
    func numberOfSections(in _: ASCollectionNode) -> Int {
        dataSource
            .numberOfSections
    }

    func collectionNode(_: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        dataSource
            .numberOfItems(in: section)
    }
}

// MARK: Node for Item At

extension Controller: ASCollectionDelegate {
    func frameOfItem(at path: IndexPath) -> CGRect? {
        collectionNode.view.layoutAttributesForItem(at: path)?.frame
    }

    func collectionNode(_: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else {
            return {
                EmptyNode()
            }
        }

        let position = resumptionPosition
        let height = view.frame.height * 0.70
        switch item {
        case let .page(page):
            return { [weak self] in
                let node = ImageNode(page: page)
                node.delegate = self
                guard let pending = position,
                      pending.0 == page.page.index
                else {
                    return node
                }
                node.savedOffset = pending.1
                return node
            }
        case let .transition(transition):
            return {
                let node = ASCellNode(viewControllerBlock: {
                    let view = ReaderTransitionView(transition: transition)
                    let controller = UIHostingController(rootView: view)
                    return controller
                })
                node.style.width = ASDimensionMakeWithFraction(1)
                node.style.height = ASDimensionMake(height)
                return node
            }
        }
    }
}
