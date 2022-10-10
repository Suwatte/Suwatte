//
//  Vertical+ASController.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-04.
//

import UIKit
import SwiftUI
import AsyncDisplayKit
import Kingfisher
import Combine

extension VerticalViewer {
    class AsyncController: ASDKViewController<ASCollectionNode> {
        internal let model: ReaderView.ViewModel
        private let zoomTransitionDelegate = ZoomTransitioningDelegate()
        var subscriptions = Set<AnyCancellable>()
        var selectedIndexPath: IndexPath!
        var initialOffset: (Int, CGFloat?)? = nil
        // MARK: Init
        init(model: ReaderView.ViewModel) {
            let node = ASCollectionNode(collectionViewLayout: .init())
            self.model = model
            super.init(node: node)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // MARK: DeInit
        deinit {
            Logger.shared.debug("Vertical Controller Deallocated")
        }
        
        // MARK: View Did Load
        override func viewDidLoad() {
            collectionNode.delegate = self
            collectionNode.dataSource = self
            collectionNode.shouldAnimateSizeChanges = false
            collectionNode.backgroundColor = .clear
            collectionNode.insetsLayoutMarginsFromSafeArea = false
            collectionNode.alpha = 0
            setLayout()
            listen()
            navigationController?.delegate = zoomTransitionDelegate
            navigationController?.isNavigationBarHidden = true
            
            collectionNode.isPagingEnabled = false
            collectionNode.showsVerticalScrollIndicator = false
            collectionNode.showsHorizontalScrollIndicator = false
            

            let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTapGR.numberOfTapsRequired = 2
            tapGR.require(toFail: doubleTapGR)
            self.collectionNode.view.addGestureRecognizer(doubleTapGR)
            self.collectionNode.view.addGestureRecognizer(tapGR)
            collectionNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        // MARK: View DidAppear
        override func viewDidAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

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
                .firstIndex(where: { ($0 as? ReaderView.Page)?.index == requestedIndex }) ?? requestedIndex
            let path: IndexPath = .init(item: openingIndex, section: 0)
            collectionNode.scrollToItem(at: path, at: .top, animated: false)

            let point = collectionNode
                .collectionViewLayout
                .layoutAttributesForItem(at: path)?.frame.minY ?? 0
            model.slider.setCurrent(point)
            calculateCurrentChapterScrollRange()

            // TODO: Last Offset
            if let lastOffset = rChapter.requestedPageOffset {
                collectionNode.contentOffset.y += lastOffset
            }
            
            UIView.animate(withDuration: 0.2,
                           delay: 0.0,
                           options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.collectionNode.alpha = 1
            }
        }
        
    
        
        var collectionNode : ASCollectionNode {
            return node
        }
        
        var contentSize: CGSize {
            collectionNode.collectionViewLayout.collectionViewContentSize
        }
        
        fileprivate func setLayout() {
            let layout = VerticalContentOffsetPreservingLayout()
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            layout.sectionInset = UIEdgeInsets.zero
            layout.estimatedItemSize = .zero
            collectionNode.collectionViewLayout = layout
        }
        
        
    }
    
}

fileprivate typealias Controller = VerticalViewer.AsyncController

// MARK: Collection DataSource
extension Controller: ASCollectionDataSource {
    
    func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
        return model.sections.count
    }
    
    func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        return model.sections[section].count
    }
    
}

// MARK: Collection Delegate
extension Controller: ASCollectionDelegate {
    func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let data = model.getObject(atPath: indexPath)
        
        if let data = data as? ReaderView.Page {
            return {
                let node = Controller.ImageNode(page: data)
                node.delegate = self
                if let target = self.initialOffset, indexPath.section == 0, indexPath.item == target.0, let offset = target.1 {
                    node.savedOffset = offset
                }
                return node
            }
        }
        else if let data = data as? ReaderView.Transition {
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

fileprivate class EmptyNode: ASCellNode {}


extension VerticalViewer.AsyncController {
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
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
    
    func handleChapterPreload(at path: IndexPath?) {
        guard let path, let currentPath = currentPath, currentPath.section == path.section else {
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