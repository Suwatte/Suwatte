//
//  WebtoonController.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//


import AsyncDisplayKit
import OrderedCollections
import Combine
import SwiftUI
import UIKit


extension IndexPath {
    var isFirst: Bool {
        section == 0 && (item == 0 || row == 0)
    }
}
class WebtoonController: ASDKViewController<ASCollectionNode> {
    internal let model: IVViewModel
    internal var subscriptions = Set<AnyCancellable>()
    internal var timer: Timer?
    internal var isZooming = false
    internal var dataSource = WCDataSource()
    internal var resumptionPosition: (Int, CGFloat)?
    internal var preRotationPath: IndexPath?
    internal var preRotationOffset: CGFloat?
    internal var lastIndexPath: IndexPath = .init(item: 0, section: 0)
    internal var currentChapterRange: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
    internal var didTriggerBackTick = false
    internal var lastKnownScrollPosition: CGFloat = 0.0
    internal var scrollPositionUpdateThreshold: CGFloat = 30.0
    internal var currentZoomingIndexPath: IndexPath!
    private let zoomTransitionDelegate = ZoomTransitioningDelegate()
    internal var onPageReadTask: Task<Void, Never>?

    // Computed
    internal var dataCache: IVDataCache {
        model.dataCache
    }
    
    internal var collectionNode: ASCollectionNode {
        return node
    }

    internal var contentSize: CGSize {
        collectionNode.collectionViewLayout.collectionViewContentSize
    }
    
    internal var offset: CGFloat {
        collectionNode.contentOffset.y
    }
    
    internal var currentPoint: CGPoint {
        collectionNode.view.currentPoint
    }

    internal var currentPath: IndexPath? {
        collectionNode.view.pathAtCenterOfScreen
    }
    
    internal var pathAtCenterOfScreen: IndexPath? {
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
    
    deinit {
        timer = nil
        NotificationCenter
            .default
            .removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        Logger.shared.debug("controller deallocated", "WebtoonController")
    }
    
    // Core
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
        self.startup()
        self.subscribeAll()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isZooming {
            isZooming = false
            return
        }
    }
    
    @objc internal func appMovedToBackground() {
        cancelAutoScroll()
    }
    
    internal func presentNode() {
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


fileprivate typealias Controller = WebtoonController

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
    
    func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else {
            return {
                EmptyNode()
            }
        }
        
        switch item {
            case .page(let page):
                return { [weak self] in
                    let node = ImageNode(page: page)
                    node.delegate = self
                    guard let pending = self?.resumptionPosition,
                          pending.0 == indexPath.item else {
                        return node
                    }
                    node.savedOffset = pending.1
                    return node
                }
            case .transition(let transition):
                let height = view.frame.height * 0.66
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

