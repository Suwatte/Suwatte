//
//  IV+ZoomingScrollView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-05.
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

    func standardSize() {
        guard let target else { return }
        NSLayoutConstraint.activate([
            target.heightAnchor.constraint(equalTo: wrapper.heightAnchor),
            target.widthAnchor.constraint(equalTo: wrapper.widthAnchor),
            target.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            target.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),

            wrapper.heightAnchor.constraint(equalTo: heightAnchor),
            wrapper.widthAnchor.constraint(equalTo: widthAnchor),
            wrapper.centerXAnchor.constraint(equalTo: centerXAnchor),
            wrapper.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    var postImageSetConstraints: [NSLayoutConstraint] = []
    func didUpdateSize(size: CGSize) {
        guard let target else { return }
        // Make Target Center The Center of The Wrapper As Well
        postImageSetConstraints.append(contentsOf: [
            target.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            target.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])

        // IF the Size is Less Than the Width of the ScrollView, Set the Wrapper's Center X & Width to match that of the scrollview
        if size.width <= frame.width {
            postImageSetConstraints.append(contentsOf:
                [
                    wrapper.centerXAnchor.constraint(equalTo: centerXAnchor),
                    wrapper.widthAnchor.constraint(equalTo: widthAnchor),
                ]
            )
        } else {
            // In Situations where the wrappers width is greater than the width of the ScrollView, The Wrapper & Target Height will ALWAYS be the height of the scrollView (Fit Height & Stretch)
            // Set the Wrappers Height Constraint to Match that of the scrollView
            postImageSetConstraints.append(wrapper.heightAnchor.constraint(equalTo: heightAnchor))
            // Set the Wrappers Width Constraint to Be Relative To the Set Height Using the Desired Size Ratio
            let multiplier = size.width / size.height
            postImageSetConstraints.append(wrapper.widthAnchor.constraint(equalTo: wrapper.heightAnchor, multiplier: multiplier))
        }

        // IF the height is less than the height of the scrollview, set the wrappers Center Y & Height to match that of the scrollview
        if size.height <= frame.height {
            postImageSetConstraints.append(contentsOf:
                [
                    wrapper.centerYAnchor.constraint(equalTo: centerYAnchor),
                    wrapper.heightAnchor.constraint(equalTo: heightAnchor),
                ]
            )
        } else {
            // In Situations where the wrappers's height is greather than the height of the scrollView, The Wrapper & Target's width will ALWAYS be the width of the ScrollView (Fit Width // Stretch)

            // Set the wrappers width constraint to match its width of the scrollView
            postImageSetConstraints.append(wrapper.widthAnchor.constraint(equalTo: widthAnchor))

            // Set the Wrappers Height Constraint to be relative to its width using the desired size ratio
            let multiplier = size.height / size.width
            postImageSetConstraints.append(wrapper.heightAnchor.constraint(equalTo: wrapper.widthAnchor, multiplier: multiplier))
        }

        // Activate Wrapper Constraints
        NSLayoutConstraint.activate(postImageSetConstraints)

        // Activate Layout Guide Constraints
        NSLayoutConstraint.activate([
            contentLayoutGuide.topAnchor.constraint(equalTo: wrapper.topAnchor),
            contentLayoutGuide.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            contentLayoutGuide.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            contentLayoutGuide.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])

        contentSize = size
    }

    func setZoomPosition() {
        guard contentSize.width > frame.width else {
            return
        }

        // TODO: Maybe make this react to both left & right swipes?
        let ltr = Preferences.standard.readingLeftToRight
        let isVerticalPager = Preferences.standard.isPagingVertically
        if ltr || isVerticalPager { return } // Reading Left to Right/ 1 --> 2, Already Set to Start at X == 0

        contentOffset = .init(x: contentSize.width, y: 0)
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
    
    func resetConstraints() {
        for constraint in postImageSetConstraints {
            constraint.isActive = false
            constraint.priority = .defaultLow
        }
        
        postImageSetConstraints.removeAll()
    }
}
