//
//  ImageScrollView.swift
//  PhotoScroller
//
//  Created by Seyed Samad Gholamzadeh on 1/14/18.
//  Copyright © 2018 Seyed Samad Gholamzadeh. All rights reserved.
//
import UIKit

class VerticalImageScrollView: UIScrollView, UIScrollViewDelegate {
    var zoomView: UIImageView!
    weak var linkDelegate: VerticalImageScrollDelegate?
    lazy var zoomingTap: UITapGestureRecognizer = {
        let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
        zoomingTap.numberOfTapsRequired = 2

        return zoomingTap
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        centerImage()
    }

    // MARK: - Configure scrollView to display new image

    var initialRect: CGRect?
    func display(_ image: UIImage) {
        // 1. clear the previous image
        zoomView?.removeFromSuperview()
        zoomView = nil

        // 2. make a new UIImageView for the new image
        zoomView = UIImageView(image: image)

        zoomView.contentMode = .scaleAspectFit

        addSubview(zoomView)
        configureFor(image.size)
    }

    func configureFor(_ imageSize: CGSize) {
        contentSize = imageSize
        setMaxMinZoomScaleForCurrentBounds()
        zoomScale = minimumZoomScale

        // Enable zoom tap
        zoomView.addGestureRecognizer(zoomingTap)
        zoomView.isUserInteractionEnabled = true
    }

    func setMaxMinZoomScaleForCurrentBounds() {
        let boundsSize = bounds.size
        let imageSize = zoomView.bounds.size
        // 1. calculate minimumZoomscale
        let xScale = boundsSize.width / imageSize.width // the scale needed to perfectly fit the image width-wise
//        let yScale = boundsSize.height / imageSize.height // the scale needed to perfectly fit the image height-wise

//        let minScale = min(xScale, yScale) // use minimum of these to allow the image to become fully visible
        let minScale = xScale // Use only xScale to make image fit width
        // 2. calculate maximumZoomscale

        maximumZoomScale = 3.5
        minimumZoomScale = minScale
    }

    func centerImage() {
        // center the zoom view as it becomes smaller than the size of the screen
        let boundsSize = bounds.size
        var frameToCenter = zoomView?.frame ?? CGRect.zero

        // center horizontally
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        // center vertically
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        zoomView?.frame = frameToCenter
    }

    // MARK: - UIScrollView Delegate Methods

    func viewForZooming(in _: UIScrollView) -> UIView? {
        return zoomView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        centerImage()
    }

    func scrollViewDidEndZooming(_: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        linkDelegate?.didEndZooming(scale, out, view)
    }

    // MARK: - Methods called during rotation to preserve the zoomScale and the visible portion of the image

    // returns the center point, in image coordinate space, to try restore after rotation.
    func pointToCenterAfterRotation() -> CGPoint {
        let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        return convert(boundsCenter, to: zoomView)
    }

    // returns the zoom scale to attempt to restore after rotation.
    func scaleToRestoreAfterRotation() -> CGFloat {
        var contentScale = zoomScale

        // If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
        // allowable scale when the scale is restored.
        if contentScale <= minimumZoomScale + CGFloat.ulpOfOne {
            contentScale = 0
        }

        return contentScale
    }

    func maximumContentOffset() -> CGPoint {
        let contentSize = self.contentSize
        let boundSize = bounds.size
        return CGPoint(x: contentSize.width - boundSize.width, y: contentSize.height - boundSize.height)
    }

    func minimumContentOffset() -> CGPoint {
        return CGPoint.zero
    }

    func restoreCenterPoint(to oldCenter: CGPoint, oldScale: CGFloat) {
        // Step 1: restore zoom scale, first making sure it is within the allowable range.
        zoomScale = min(maximumZoomScale, max(minimumZoomScale, oldScale))

        // Step 2: restore center point, first making sure it is within the allowable range.

        // 2a: convert our desired center point back to our own coordinate space
        let boundsCenter = convert(oldCenter, from: zoomView)
        // 2b: calculate the content offset that would yield that center point
        var offset = CGPoint(x: boundsCenter.x - bounds.size.width / 2.0, y: boundsCenter.y - bounds.size.height / 2.0)
        // 2c: restore offset, adjusted to be within the allowable range
        let maxOffset = maximumContentOffset()
        let minOffset = minimumContentOffset()
        offset.x = max(minOffset.x, min(maxOffset.x, offset.x))
        offset.y = max(minOffset.y, min(maxOffset.y, offset.y))
        contentOffset = offset
    }

    // MARK: - Handle ZoomTap

    @objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sender.view) // Location in Image View
        out.inWindow = sender.location(in: nil) // Location in Window
        out.inView = location
        zoom(to: location, animated: true)
    }

    var out: (inWindow: CGPoint?, inView: CGPoint?) = (nil, nil)
    func zoom(to point: CGPoint, animated: Bool) {
        let currentScale = zoomScale
        let minScale = minimumZoomScale
        let maxScale = 2.0

        if minScale == maxScale, minScale > 1 {
            return
        }

        let toScale = maxScale
        let finalScale = (currentScale == minScale) ? toScale : minScale
        let zoomRect = self.zoomRect(for: finalScale, withCenter: point)

        zoom(to: zoomRect, animated: animated)
    }

    // The center should be in the imageView's coordinates
    func zoomRect(for scale: CGFloat, withCenter center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        let bounds = self.bounds

        // the zoom rect is in the content view's coordinates.
        // At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
        // As the zoom scale decreases, so more content is visible, the size of the rect grows.
        zoomRect.size.width = bounds.size.width / scale
        zoomRect.size.height = bounds.size.height / scale

        // choose an origin so as to get the right center.
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)

        return zoomRect
    }
}
