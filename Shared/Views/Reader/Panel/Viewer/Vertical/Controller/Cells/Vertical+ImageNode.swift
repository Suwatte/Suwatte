//
//  Vertical+ImageNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import Combine
import UIKit
import Nuke

private typealias Controller = VerticalViewer.Controller
extension Controller {
    class ImageNode: ASCellNode {
        let imageNode = ASImageNode()
        var progressNode: ProgressNode
        let progressModel = ReaderView.ProgressObject()
        let page: ReaderView.Page
        var ratio: CGFloat?
        weak var delegate: VerticalViewer.Controller?
        var savedOffset: CGFloat?
        var working = false
        var isZoomed = false
        private weak var nukeTask: AsyncImageTask?
        var subscriptions = Set<AnyCancellable>()
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
            
            Task.detached { [weak self] in
                do {
                    let task = try await self?.page.load()
                    
                    guard let task else {
                        return
                    }
                    for await progress in task.progress {
                        // Update progress
                        await MainActor.run { [weak self] in
                            self?.handleProgressBlock(progress.fraction)
                        }
                    }
                    
                    let image = try await task.image
                    await MainActor.run { [weak self] in
                        self?.didLoadImage(image)
                        self?.nukeTask = nil
                    }
                    
                } catch {
                    await MainActor.run { [weak self] in
                        self?.didFailToLoadImage(error)
                    }
                }
                await MainActor.run { [weak self] in
                    self?.working = false
                }
            }
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
                listen()
            }
        }

        
        func didLoadImage(_ image: UIImage) {
            self.image = image
            if isNodeLoaded {
                displayImage()
            }
        }
        func didFailToLoadImage(_ error: Error) {
            handleImageFailure(error)
        }

        override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
            if let image {
                if Preferences.standard.usePillarBox {
                    var pct = CGFloat(Preferences.standard.pillarBoxPCT)
                    // Guards
                    pct = max(pct, 0.15)
                    pct = min(pct, 1.0)

                    imageNode.style.width = ASDimensionMakeWithFraction(pct)
                    // Height Calculations
                    let width = constrainedSize.max.width * pct
                    let height = width / image.size.ratio
                    imageNode.style.height = ASDimensionMakeWithPoints(height)
                    let n = ASDisplayNode()
                    n.style.width = ASDimensionMake("100%")
                    imageNode.style.alignSelf = .center
                    let base = ASRelativeLayoutSpec(horizontalPosition: .center, verticalPosition: .center, sizingOption: [], child: imageNode)
                    return ASAbsoluteLayoutSpec(children: [n, base])
                } else {
                    return ASRatioLayoutSpec(ratio: 1 / image.size.ratio, child: imageNode)
                }

            } else {
                let ratio = 1 / UIScreen.main.bounds.size.ratio
                return ASRatioLayoutSpec(ratio: ratio, child: progressNode)
            }
        }

        func handleProgressBlock(_ progress: Float) {
            (progressNode.view as? CircularProgressBar)?.setProgress(to: Double(progress), withAnimation: false)
        }

        func handleImageFailure(_ error: Error) {
            progressModel.setError(error, setImage)
            progressNode.isHidden = false
        }

        func didFinishImageTasks() {
            working = false
        }

        func listen() {
            Preferences.standard.preferencesChangedSubject
                .filter { changedKeyPath in
                    changedKeyPath == \Preferences.usePillarBox ||
                        changedKeyPath == \Preferences.pillarBoxPCT
                }
                .sink { [weak self] _ in
                    guard let image = self?.image else { return }
                    let size = image.size.scaledTo(UIScreen.main.bounds.size)
                    self?.frame = .init(origin: .init(x: 0, y: 0), size: size)
                    self?.ratio = size.height / size.width
                    self?.transitionLayout(with: .init(min: size, max: size), animated: true, shouldMeasureAsync: false)
                }
                .store(in: &subscriptions)
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
    }

    override func didExitVisibleState() {
        super.didExitVisibleState()
        if isZoomed { return }
        nukeTask?.cancel()
        imageNode.view.removeGestureRecognizer(menuTap)
        imageNode.view.removeGestureRecognizer(zoomingTap)
        imageNode.image = nil
        image = nil
        ratio = nil
        imageNode.alpha = 0
        progressNode.alpha = 1
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }
}
