//
//  ImageNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-19.
//

import AsyncDisplayKit
import Combine
import Nuke
import UIKit

class ImageNode: ASCellNode {
    let imageNode = BareBonesImageNode()
    private let progressNode = ASDisplayNode(viewBlock: {
        CircularProgressView()
    })
    private let page: PanelPage
    private var ratio: CGFloat?
    weak var delegate: WebtoonController?
    var savedOffset: CGFloat?
    private var isZoomed: Bool {
        delegate?.isZooming ?? false
    }

    private weak var nukeTask: ImageTask?
    private var imageTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var contextMenuEnabled: Bool {
        Preferences.standard.imageInteractions
    }

    private var hasTriggeredChapterDelegateCall = false
    private var isWorking = false
    private var imageSetup = false

    var isLeading: Bool {
        let collectionNode = owningNode as? ASCollectionNode
        guard let collectionNode, let indexPath else { return false }
        let yOrigin = collectionNode.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame.origin.y
        guard let yOrigin else { return false }
        return yOrigin < collectionNode.contentOffset.y
    }

    private var downsample: Bool {
        Preferences.standard.downsampleImages
    }

    init(page: PanelPage) {
        self.page = page
        super.init()
        shouldAnimateSizeChanges = false
        automaticallyManagesSubnodes = true
        backgroundColor = .clear
        progressNode.backgroundColor = .clear
        imageNode.isUserInteractionEnabled = false
        imageNode.shouldAnimateSizeChanges = false
        imageNode.alpha = 0
        imageNode.backgroundColor = .clear
        // ;-;
        imageNode.shadowRadius = .zero
        imageNode.shadowOffset = .zero
        shadowRadius = .zero
        shadowRadius = .zero
    }

    func listen() {
        // Pillarbox
        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.usePillarBox ||
                    changedKeyPath == \Preferences.pillarBoxPCT
            }
            .sink { [weak self] _ in
                guard let image = self?.imageNode.image else { return }
                let size = image.size.scaledTo(UIScreen.main.bounds.size)
                self?.frame = .init(origin: .init(x: 0, y: 0), size: size)
                self?.ratio = size.height / size.width
                self?.transitionLayout(with: .init(min: size, max: size), animated: true, shouldMeasureAsync: false)
            }
            .store(in: &subscriptions)

        Preferences
            .standard
            .preferencesChangedSubject
            .filter { path in
                path == \Preferences.downsampleImages
            }
            .sink { [weak self] _ in
                self?.imageNode.image = nil
                self?.loadImage()
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Node State

extension ImageNode {
    override func didEnterDisplayState() {
        super.didEnterDisplayState()
    }

    override func didEnterPreloadState() {
        super.didEnterPreloadState()
        loadImage()
    }

    override func didEnterVisibleState() {
        super.didEnterVisibleState()
        guard imageNode.image == nil else { return }
        loadImage()
    }

    override func didExitVisibleState() {
        super.didExitVisibleState()
        if isZoomed { return }
        cancel()
        checkIfChapterDelegateShouldBeCalled()
    }
}

// MARK: - Layout

extension ImageNode {
    override func animateLayoutTransition(_ context: ASContextTransitioning) {
        defer {
            UIView.animate(withDuration: 0.33,
                           delay: 0,
                           options: [.transitionCrossDissolve, .allowUserInteraction, .curveEaseInOut])
            { [unowned self] in
                if ratio != nil {
                    imageNode.alpha = 1
                    progressNode.alpha = 0
                } else {
                    imageNode.alpha = 0
                    progressNode.alpha = 1
                }
            }
        }
        imageNode.frame = context.finalFrame(for: imageNode)
        context.completeTransition(true)
        Task { @MainActor in
            delegate?.updateChapterScrollRange()
            delegate?.setScrollPCT()
        }

        // Inserting At Top
        let manager = owningNode as? ASCollectionNode
        let layout = manager?.collectionViewLayout as? VImageViewerLayout

        guard let layout, let manager, let indexPath else { return }
        let Y = manager.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame.origin.y
        guard let Y else { return }
        layout.isInsertingCellsToTop = Y < manager.contentOffset.y
        guard let savedOffset else {
            return
        }

        let requestedOffset = imageNode.frame.height * savedOffset
        manager.contentOffset.y += requestedOffset
        self.savedOffset = nil
        delegate?.clearResumption()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        if let image = imageNode.image {
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
}

// MARK: - Image

extension ImageNode {
    func didLoadImage(_ image: UIImage) {
        guard isNodeLoaded else { return }
        displayImage(image)
        resetTasks()
    }

    func handleProgressBlock(_ progress: Double) {
        (progressNode.view as? CircularProgressView)?
            .setProgress(to: progress, withAnimation: false)
    }

    func handleImageFailure(_: Error) {
        imageNode.alpha = 0
        progressNode.alpha = 1
    }

    private func resetTasks() {
        imageTask = nil
        nukeTask = nil
        isWorking = false
    }

    private func resetNukeTasksAsync() async {
        await MainActor.run { [weak self] in
            self?.nukeTask = nil
            self?.isWorking = false
        }
    }

    private func cancel() {
        imageTask?.cancel()
        nukeTask?.cancel()
        imageTask = nil
        nukeTask = nil
        isWorking = false
    }
}

extension ImageNode {
    func loadImage() {
        guard !isWorking, imageNode.image == nil else {
            return
        }
        isWorking = true

        let page = page
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let data: PanelActor.PageData = .init(data: page,
                                              size: frame.size,
                                              fitToWidth: true,
                                              isPad: isPad)
        imageTask = Task { [weak self] in
            await PanelActor.run { [weak self] in
                do {
                    let request = try await PanelActor.shared.loadPage(for: data)

                    guard !Task.isCancelled else {
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    for await progress in request.progress {
                        // Update progress
                        let p = Double(progress.fraction)
                        await MainActor.run { [weak self] in
                            self?.handleProgressBlock(p)
                        }
                    }

                    guard !Task.isCancelled else {
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    let image = try await request.image

                    guard !Task.isCancelled else {
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    await MainActor.run { [weak self] in
                        self?.didLoadImage(image)
                    }

                } catch {
                    if error is CancellationError {
                        await self?.resetNukeTasksAsync()
                        return
                    }
                    Logger.shared.error(error, page.page.chapter.sourceId)
                    await MainActor.run { [weak self] in
                        self?.handleImageFailure(error)
                    }
                }

                await self?.resetNukeTasksAsync()
            }
        }
    }

    func displayImage(_ image: UIImage) {
        guard imageNode.image == nil else {
            if !imageSetup {
                postImageSetSetup()
            }
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
        Task { @MainActor [weak self] in
            self?.postImageSetSetup()
        }
    }

    func postImageSetSetup() {
        listen()
        imageSetup = true
        imageTask = nil
        nukeTask = nil
        isWorking = false
        guard imageNode.alpha == 0 else { return }
        UIView.animate(withDuration: 0.33,
                       delay: 0,
                       options: [.transitionCrossDissolve, .allowUserInteraction, .curveEaseInOut])
        { [unowned self] in
            imageNode.alpha = 1
            progressNode.alpha = 0
        }
    }

    func checkIfChapterDelegateShouldBeCalled() {
        guard page.page.isLastPage,
              !hasTriggeredChapterDelegateCall,
              let delegate,
              let indexPath,
              let maxY = delegate.frameOfItem(at: indexPath)?.maxY,
              maxY < delegate.offset else { return }

        delegate.didCompleteChapter(page.page.chapter)
        hasTriggeredChapterDelegateCall = true
    }
}

// MARK: - Bare Bones Image Node

class BareBonesImageNode: ASDisplayNode {
    var image: UIImage?

    class Params: NSObject {
        var image: UIImage?
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        guard let image else {
            let prepped = super.calculateSizeThatFits(constrainedSize)
            return prepped
        }
        return image.size.scaledTo(UIScreen.main.bounds.size)
    }

    override func drawParameters(forAsyncLayer _: _ASDisplayLayer) -> NSObjectProtocol? {
        let params = Params()
        params.image = image
        return params
    }

    override class func display(withParameters parameters: Any?, isCancelled _: () -> Bool) -> UIImage? {
        guard let params = parameters as? Params, let image = params.image else {
            return nil
        }

        return image
    }
}
