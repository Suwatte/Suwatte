//
//  Vertical+ASController.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-04.
//

import UIKit
import AsyncDisplayKit
import Kingfisher

extension VerticalViewer {
    class AsyncController: ASDKViewController<ASCollectionNode> {
        let model: ReaderView.ViewModel
        var cache: [IndexPath: CGSize] = [:]
        
        init(model: ReaderView.ViewModel) {
            let node = ASCollectionNode(collectionViewLayout: VerticalContentOffsetPreservingLayout())
            self.model = model
            super.init(node: node)
        }
        override func viewDidLoad() {
            collectionNode.delegate = self
            collectionNode.dataSource = self
            self.view.backgroundColor = .red
            navigationController?.isNavigationBarHidden = true

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var collectionNode : ASCollectionNode {
            return node
        }
        
    }
    
}

private typealias Controller = VerticalViewer.AsyncController
private typealias ImageCell = VerticalImageCell

extension Controller: ASCollectionDelegate, ASCollectionDataSource {
    
    func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
        return model.sections.count
    }
    
    func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
        return model.sections[section].count
    }
    
    func collectionNode(_ collectionNode: ASCollectionNode, willDisplayItemWith node: ASCellNode) {
        if let node = node as? ImageNode {
            node.setImage()
        }
    }
    
    func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
        let data = model.getObject(atPath: indexPath)
        
        if let data = data as? ReaderView.Page {
            return {
                let node = ImageNode(page: data, c: self)
                return node
            }
        } else {
            return {
                return ShopCellNode()
            }
        }
        
    }
    
    func test(path: IndexPath, size: CGSize) {
        //        cache[path] = size.scaledTo(self.collectionNode.frame.size)
        //        self.collectionNode.invalidateCalculatedLayout()
    }
    
    //    func collectionNode(_ collectionNode: ASCollectionNode, constrainedSizeForItemAt indexPath: IndexPath) -> ASSizeRange {
    //        let size = cache[indexPath] ?? (collectionNode.frame.size)
    //        return .init(min: collectionNode.frame.size, max: size)
    //    }
    
}

fileprivate class ImageNode: ASCellNode {
    let imageNode = ASDisplayNode { () -> UIImageView in
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }
    let page: ReaderView.Page
    var delegate: Controller? = nil
    var ratio: CGFloat? = nil
    init(page: ReaderView.Page, c: Controller) {
        self.page = page
        self.delegate = c
        super.init()
        self.automaticallyManagesSubnodes = true
        self.backgroundColor = .randomColor()
        
    }
    
    func setImage() {
        
        guard ratio == nil else { return }
        let kfOptions: [KingfisherOptionsInfoItem] = [
            .scaleFactor(UIScreen.main.scale),
            .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
            .requestModifier(AsyncImageModifier(sourceId: page.sourceId)),
            .backgroundDecode,
        ]
        guard let source = page.toKFSource()else {
            return
        }
        
        KingfisherManager.shared.retrieveImage(with: source,
                                               options: kfOptions,
                                               progressBlock: { [weak self] in self?.handleProgressBlock($0, $1, source) },
                                               completionHandler: { [weak self] in self?.onImageProvided($0) })
    }
    
    override func animateLayoutTransition(_ context: ASContextTransitioning) {
        if context.isAnimated() {
            imageNode.frame = context.finalFrame(for: imageNode)
            context.completeTransition(true)
        } else {
            super.animateLayoutTransition(context)
        }
    }
    func onImageProvided(_ result: Result<RetrieveImageResult, KingfisherError>) {
        switch result {
            case let .success(imageResult):
                if page.CELL_KEY != imageResult.source.cacheKey {
                    //                working = false
                    return
                }

                (imageNode.view as? UIImageView)?.image = imageResult.image
                let size = imageResult.image.size.scaledTo(UIScreen.main.bounds.size)
                self.frame = .init(origin: .init(x: 0, y: 0), size: size)
                ratio = size.height / size.width
                transitionLayout(with: .init(min: .zero, max: size), animated: false, shouldMeasureAsync: false)

                            
                //            DispatchQueue.main.async { [weak self] in
                ////                guard let self = self else {
                ////                    return
                ////                }
                //                print("SET NODE", self?.page)
                ////                self.imageView.image = imageResult.image
                //
                ////                self.resizeDelegate?.didLoadImage(at: self.indexPath, with: imageResult.image.size)
                ////                UIView.transition(with: self.imageView,
                ////                                  duration: 0.33,
                ////                                  options: [.transitionCrossDissolve, .allowUserInteraction],
                ////                                  animations: {
                //////                                      self.progressView.isHidden = true
                ////
                ////                                  }) { _ in
                ////                    self.imageView.addGestureRecognizer(self.zoomingTap)
                ////                    self.imageView.isUserInteractionEnabled = true
                ////                    self.working = false
                ////                }
                //            }
                
                //
            case let .failure(error):
                
                if error.isNotCurrentTask || error.isTaskCancelled {
                    return
                }
                
                //            handleImageFailure(error)
        }
    }
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
       
        let imagePlace = ASRatioLayoutSpec(ratio: ratio ?? 2.5, child: imageNode)
        return imagePlace
    }

    func handleProgressBlock(_ recieved: Int64, _ total: Int64, _ source: Kingfisher.Source) {
        if source.cacheKey != page.CELL_KEY {
            //            downloadTask?.cancel()
            return
        }
        //        progressModel.setProgress(CGFloat(recieved) / CGFloat(total))
    }
    
}


class ShopCellNode: ASCellNode {
    
    // MARK: - Object life cycle
    
    override init() {
        super.init()
        self.selectionStyle = .none
        self.backgroundColor = .randomColor()
    }
    
    
    
    //    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    //        ASLayoutSpec()
    //    }
}
