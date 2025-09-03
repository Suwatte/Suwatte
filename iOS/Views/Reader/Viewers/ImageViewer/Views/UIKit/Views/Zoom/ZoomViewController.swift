//
//  ZoomViewController.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-15.
//

import AsyncDisplayKit
import UIKit

protocol ZoomHandlerDelegate: UIViewController {
    func cellTappedAt(point: CGPoint, frame: CGRect, path: IndexPath)
}

protocol ZoomableHostDelegate: NSObject {
    var collectionNode: ASCollectionNode { get }
    var currentZoomingIndexPath: IndexPath! { get set }
}

protocol VerticalImageScrollDelegate: AnyObject {
    func didEndZooming(_ scale: CGFloat, _ points: (inWindow: CGPoint?, inView: CGPoint?)?, _ view: UIView?)
}

@objc
protocol ZoomingViewController {
    func zoomingImageView(for transition: ZoomTransitioningDelegate) -> UIView?
    func zoomingImage(for transition: ZoomTransitioningDelegate) -> UIImage?
    func zoomingBackgroundView(for transition: ZoomTransitioningDelegate) -> UIView?
}

enum TransitionState {
    case initial
    case final
}

class ZoomTransitioningDelegate: NSObject {
    var transitionDuration = 0.5
    var operation: UINavigationController.Operation = .none
    typealias ZoomingViews = (otherView: UIView, imageView: UIView)

    func configureViews(for state: TransitionState, containerView: UIView, backgroundViewController: UIViewController, viewsInBackground: ZoomingViews, viewsInForeground: ZoomingViews, snapshotViews: ZoomingViews) {
        switch state {
        case .initial:
            backgroundViewController.view.alpha = 1

            snapshotViews.imageView.frame = containerView.convert(viewsInBackground.imageView.frame, from: viewsInBackground.imageView.superview)

        case .final:
            backgroundViewController.view.alpha = 0

            snapshotViews.imageView.frame = containerView.convert(viewsInForeground.imageView.frame, from: viewsInForeground.imageView.superview)
        }
    }
}

extension ZoomTransitioningDelegate: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        let fromViewController = transitionContext.viewController(forKey: .from)!
        let toViewController = transitionContext.viewController(forKey: .to)!
        let containerView = transitionContext.containerView

        var backgroundViewController = fromViewController
        var foregroundViewController = toViewController

        if operation == .pop {
            backgroundViewController = toViewController
            foregroundViewController = fromViewController
        }

        let maybeBackgroundImageView = (backgroundViewController as? ZoomingViewController)?.zoomingImageView(for: self)
        let maybeForegroundImageView = (foregroundViewController as? ZoomingViewController)?.zoomingImageView(for: self)

        let image = (backgroundViewController as? ZoomingViewController)?.zoomingImage(for: self)
        assert(maybeBackgroundImageView != nil, "Cannot find imageView in backgroundVC")
        assert(maybeForegroundImageView != nil, "Cannot find imageView in foregroundVC")
        assert(image != nil, "Image Not Found in backgroundVC")

        let backgroundImageView = maybeBackgroundImageView!
        let foregroundImageView = maybeForegroundImageView!

        let imageViewSnapshot = UIImageView(image: image!)

        backgroundImageView.isHidden = true
        foregroundImageView.isHidden = true
        let foregroundViewBackgroundColor = foregroundViewController.view.backgroundColor
        foregroundViewController.view.backgroundColor = UIColor.clear
        containerView.backgroundColor = .clear

        containerView.addSubview(backgroundViewController.view)
        containerView.addSubview(foregroundViewController.view)
        containerView.addSubview(imageViewSnapshot)

        var preTransitionState = TransitionState.initial
        var postTransitionState = TransitionState.final

        if operation == .pop {
            preTransitionState = .final
            postTransitionState = .initial
        }

        configureViews(for: preTransitionState, containerView: containerView, backgroundViewController: backgroundViewController, viewsInBackground: (backgroundImageView, backgroundImageView), viewsInForeground: (foregroundImageView, foregroundImageView), snapshotViews: (imageViewSnapshot, imageViewSnapshot))

        foregroundViewController.view.layoutIfNeeded()

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.configureViews(for: postTransitionState, containerView: containerView, backgroundViewController: backgroundViewController, viewsInBackground: (backgroundImageView, backgroundImageView), viewsInForeground: (foregroundImageView, foregroundImageView), snapshotViews: (imageViewSnapshot, imageViewSnapshot))

        }) { _ in
            imageViewSnapshot.removeFromSuperview()
            backgroundImageView.isHidden = false
            foregroundImageView.isHidden = false
            foregroundViewController.view.backgroundColor = foregroundViewBackgroundColor

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension ZoomTransitioningDelegate: UINavigationControllerDelegate {
    func navigationController(_: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if fromVC is ZoomingViewController, toVC is ZoomingViewController {
            self.operation = operation
            return self
        } else {
            return nil
        }
    }
}

class VerticalZoomableView: UIViewController, VerticalImageScrollDelegate {
    var imageScrollView: VerticalImageScrollView!
    var image: UIImage!
    var location: CGPoint!
    var rect: CGRect!
    var hostDelegate: ZoomableHostDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        imageScrollView = VerticalImageScrollView(frame: view.bounds)
        imageScrollView.linkDelegate = self
        view.addSubview(imageScrollView)
        layoutImageScrollView()
        imageScrollView.display(image)
    }

    func didEndZooming(_ scale: CGFloat, _ points: (inWindow: CGPoint?, inView: CGPoint?)? = nil, _ view: UIView?) {
        if scale > imageScrollView.minimumZoomScale { return }

        if let pointInView = points?.inView, let path = hostDelegate?.currentZoomingIndexPath, let cellFrame = hostDelegate?.collectionNode.collectionViewLayout.layoutAttributesForItem(at: path)?.frame, let targetView = view {
            let shouldCenter = targetView.frame.height < UIScreen.main.bounds.height
            if shouldCenter {
                hostDelegate?.collectionNode.scrollToItem(at: path, at: .centeredVertically, animated: false)
            } else {
                let convertedPoint = pointInView.convert(from: targetView.bounds, to: targetView.frame)
                let offset = convertedPoint.y + cellFrame.minY - (hostDelegate?.collectionNode.frame.midY ?? 0)
                hostDelegate?.collectionNode.contentOffset.y = offset
            }
        }
        navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let convertedPoint = location.convert(from: rect, to: imageScrollView.zoomView.bounds)
        imageScrollView.zoom(to: convertedPoint, animated: true)
    }

    func layoutImageScrollView() {
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            imageScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}

extension VerticalZoomableView: ZoomingViewController {
    func zoomingImage(for _: ZoomTransitioningDelegate) -> UIImage? {
        image
    }

    func zoomingImageView(for _: ZoomTransitioningDelegate) -> UIView? {
        imageScrollView.zoomView
    }

    func zoomingBackgroundView(for _: ZoomTransitioningDelegate) -> UIView? {
        nil
    }
}

extension CGPoint {
    func convert(from: CGRect, to: CGRect) -> CGPoint {
        let outX = (to.size.width / from.size.width) * x
        let outY = (to.size.height / from.size.height) * y

        return .init(x: outX, y: outY)
    }
}
