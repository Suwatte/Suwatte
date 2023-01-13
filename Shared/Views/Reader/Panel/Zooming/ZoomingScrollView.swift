//
//  ZoomingScrollView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-31.
//

import UIKit

class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    // The Actual Content
    weak var target: UIView? {
        didSet {
            if let target = target {
                didAddTarget(view: target)
            }
        }
    }

    // A Wrapper matching the frame of the screen
    var wrapper: UIView!

    lazy var zoomingTap: UITapGestureRecognizer = {
        let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
        zoomingTap.numberOfTapsRequired = 2
        return zoomingTap
    }()
    
    func setup() {
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        minimumZoomScale = 1
        maximumZoomScale = 2
        bounces = false
        wrapper = UIView(frame: .zero)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wrapper)
    }

    func didAddTarget(view: UIView) {
        wrapper.addSubview(view)
    }
    
    
    var postImageSetConstraints: [NSLayoutConstraint] = []
    func didUpdateSize(size: CGSize){
        guard let target else { return }
        postImageSetConstraints.append(contentsOf: [
            wrapper.widthAnchor.constraint(equalToConstant: size.width),
            wrapper.heightAnchor.constraint(equalToConstant: size.height),
            target.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            target.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
        ])
        
        if size.width <= frame.width {
            postImageSetConstraints.append(
                wrapper.centerXAnchor.constraint(equalTo: centerXAnchor)
            )
        }
        
        if size.height <= frame.height {
            postImageSetConstraints.append(
                wrapper.centerYAnchor.constraint(equalTo: centerYAnchor)
            )
        }
        
        NSLayoutConstraint.activate(postImageSetConstraints)
        contentSize = size
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        wrapper
    }

    func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = frame.size.height / scale
        zoomRect.size.width = frame.size.width / scale
        let newCenter = convert(center, from: self)
        zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
}

// MARK: Gestures

extension ZoomingScrollView {
    @objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self)
        handleZoom(to: location, animated: true)
    }

    func handleZoom(to point: CGPoint, animated: Bool) {
        let currentScale = zoomScale
        let minScale = minimumZoomScale
        let maxScale = maximumZoomScale

        if minScale == maxScale, minScale > 1 {
            return
        }

        let toScale = maxScale
        let finalScale = (currentScale == minScale) ? toScale : minScale
        let zoomRect = zoomRectForScale(scale: finalScale, center: point)
        zoom(to: zoomRect, animated: animated)
    }

    func addGestures() {
        wrapper.addGestureRecognizer(zoomingTap)
        wrapper.isUserInteractionEnabled = true
        target?.isUserInteractionEnabled = true
    }

    func removeGestures() {
        wrapper.removeGestureRecognizer(zoomingTap)
        wrapper.isUserInteractionEnabled = false
        target?.isUserInteractionEnabled = false
        target?.interactions.removeAll()
        wrapper.interactions.removeAll()
    }

    func reset() {
        removeGestures()
        target?.removeFromSuperview()
        target = nil
        wrapper.removeFromSuperview()
    }
}
