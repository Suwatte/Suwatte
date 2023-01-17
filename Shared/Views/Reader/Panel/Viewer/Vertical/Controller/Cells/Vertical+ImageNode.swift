//
//  Vertical+ImageNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import Kingfisher
import UIKit

private typealias Controller = VerticalViewer.Controller
extension Controller {
    class ImageNode: ASCellNode {
        let imageNode = ASImageNode()
        var progressNode: ProgressNode
        let progressModel = ReaderView.ProgressObject()
        let page: ReaderView.Page
        var downloadTask: DownloadTask?
        var ratio: CGFloat?
        weak var delegate: VerticalViewer.Controller?
        var savedOffset: CGFloat?
        var working = false
        var isZoomed = false
        lazy var zoomingTap: UITapGestureRecognizer = {
            let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
            zoomingTap.numberOfTapsRequired = 2

            return zoomingTap
        }()

        lazy var menuTap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTapsRequired = 1
            tap.require(toFail: zoomingTap)
            return tap
        }()

        init(page: ReaderView.Page) {
            self.page = page
            progressNode = ProgressNode()
            super.init()
            shouldAnimateSizeChanges = false
            automaticallyManagesSubnodes = true
            backgroundColor = .clear
            progressNode.backgroundColor = .clear
            imageNode.backgroundColor = .clear
            imageNode.isUserInteractionEnabled = false
            imageNode.alpha = 0
        }

        func setImage() {
            guard ratio == nil, !working, image == nil else { return }

            if let savedOffset {
                transitionLayout(with: .init(min: .zero, max: .init(width: view.frame.width, height: savedOffset * 2)), animated: true, shouldMeasureAsync: false)
            }
            working = true
            var kfOptions: [KingfisherOptionsInfoItem] = [
                .scaleFactor(UIScreen.main.scale),
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
                .requestModifier(AsyncImageModifier(sourceId: page.sourceId)),
                .backgroundDecode,
            ]
            guard let source = page.toKFSource() else {
                return
            }

            var processor: ImageProcessor?

            if downsample {
                processor = STTDownsamplerProcessor()
            }

            if page.isLocal {
                kfOptions.append(.cacheMemoryOnly)
                kfOptions += [.cacheMemoryOnly]
            }

            if downsample, !page.isLocal {
                kfOptions.append(.cacheOriginalImage)
            }

            if let processor = processor {
                kfOptions.append(.processor(processor))
            }
            downloadTask = KingfisherManager.shared.retrieveImage(with: source,
                                                                  options: kfOptions,
                                                                  progressBlock: { [weak self] in self?.handleProgressBlock($0, $1, source) },
                                                                  completionHandler: { [weak self] in self?.onImageProvided($0) })
        }

        override func animateLayoutTransition(_ context: ASContextTransitioning) {
            UIView.animate(withDuration: 0.33, delay: 0, options: [.transitionCrossDissolve, .allowUserInteraction, .curveEaseInOut]) { [unowned self] in
                if ratio != nil {
                    imageNode.alpha = 1
                    progressNode.alpha = 0
                } else {
                    imageNode.alpha = 0
                    progressNode.alpha = 1
                }
            }

            imageNode.frame = context.finalFrame(for: imageNode)
            context.completeTransition(true)

            // Inserting At Top
            let manager = owningNode as? ASCollectionNode
            let layout = manager?.collectionViewLayout as? VerticalContentOffsetPreservingLayout

            guard let layout, let manager, let indexPath else { return }
            let Y = manager.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame.origin.y
            guard let Y else { return }
            layout.isInsertingCellsToTop = Y < manager.contentOffset.y
        }

        var image: UIImage?

        func displayImage() {
            guard let image else {
                setImage()
                return
            }
            imageNode.image = image
            imageNode.shouldAnimateSizeChanges = false
            let size = image.size.scaledTo(UIScreen.main.bounds.size)
            frame = .init(origin: .init(x: 0, y: 0), size: size)
            ratio = size.height / size.width
            if Task.isCancelled {
                return
            }
            transitionLayout(with: .init(min: .zero, max: size), animated: true, shouldMeasureAsync: false)
            Task { @MainActor in
                imageNode.isUserInteractionEnabled = true
                imageNode.view.addGestureRecognizer(menuTap)
                imageNode.view.addGestureRecognizer(zoomingTap)
                if let delegate, contextMenuEnabled {
                    imageNode.view.addInteraction(UIContextMenuInteraction(delegate: delegate))
                }
            }
        }

        func onImageProvided(_ result: Result<RetrieveImageResult, KingfisherError>) {
            switch result {
            case let .success(imageResult):
                if page.CELL_KEY != imageResult.source.cacheKey {
                    return
                }

                image = imageResult.image
                if isNodeLoaded {
                    displayImage()
                }

            case let .failure(error):

                if error.isNotCurrentTask || error.isTaskCancelled {
                    return
                }
                handleImageFailure(error)
            }

            didFinishImageTasks()
        }

        override func layoutSpecThatFits(_: ASSizeRange) -> ASLayoutSpec {
            if let ratio = ratio {
                let imagePlace = ASRatioLayoutSpec(ratio: ratio, child: imageNode)
                return imagePlace
            } else {
                let ratio = 1 / UIScreen.main.bounds.size.ratio
                return ASRatioLayoutSpec(ratio: ratio, child: progressNode)
            }
        }

        func handleProgressBlock(_ received: Int64, _ total: Int64, _ source: Kingfisher.Source) {
            if source.cacheKey != page.CELL_KEY {
                downloadTask?.cancel()
                return
            }
            let progress = Double(received) / Double(total)
            (progressNode.view as? CircularProgressBar)?.setProgress(to: progress, withAnimation: false)
        }

        func handleImageFailure(_ error: Error) {
            progressModel.setError(error, setImage)
            progressNode.isHidden = false
        }

        func didFinishImageTasks() {
            working = false
        }
    }
}

extension Controller.ImageNode {
    var contextMenuEnabled: Bool {
        Preferences.standard.imageInteractions
    }

    var downsample: Bool {
        Preferences.standard.downsampleImages
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        delegate?.cancelAutoScroll()

        guard let sender = sender else {
            return
        }

        let location = sender.location(in: delegate?.navigationController?.view)
        Task {
            await delegate?.model.handleNavigation(location)
        }
    }

    @objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
        delegate?.cancelAutoScroll()
        let location = sender.location(in: sender.view)
        guard let indexPath else { return }
        isZoomed = true
        delegate?.cellTappedAt(point: location, frame: sender.view!.frame, path: indexPath)
    }

    override func didEnterDisplayState() {
        super.didEnterDisplayState()
        displayImage()
    }

    override func didEnterPreloadState() {
        super.didEnterPreloadState()
        setImage()
    }

    override func didEnterVisibleState() {
        super.didEnterVisibleState()
        isZoomed = false
        displayImage()
        delegate?.handleChapterPreload(at: indexPath)
    }

    override func didExitVisibleState() {
        super.didExitVisibleState()
        if isZoomed { return }
        downloadTask?.cancel()
        imageNode.view.removeGestureRecognizer(menuTap)
        imageNode.view.removeGestureRecognizer(zoomingTap)
        imageNode.image = nil
        image = nil
        ratio = nil
        KingfisherManager.shared.cache.memoryStorage.remove(forKey: page.CELL_KEY)
        imageNode.alpha = 0
        progressNode.alpha = 1
    }
}
