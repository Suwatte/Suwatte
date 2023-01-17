//
//  Vertical+ScrollDelegate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import SwiftUI
import UIKit
private typealias Controller = VerticalViewer.Controller

extension Controller: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_: UIScrollView) {
        onScrollStop()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        onScrollStop()
    }

    func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        onScrollStop()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.y)
    }
}

extension Controller {
    var currentPoint: CGPoint {
        .init(x: collectionNode.frame.midX, y: collectionNode.contentOffset.y + collectionNode.frame.midY)
    }

    var currentPath: IndexPath? {
        collectionNode.indexPathForItem(at: currentPoint)
    }
    
    func updateSliderOffset() {
        let range = getCurrentChapterScrollRange()
        let total = range.max - range.min
        var current = collectionNode.contentOffset.y - range.min
        current = max(0, current)
        current = min(range.max, current)
        let target =  current / total
        Task { @MainActor in
            model.slider.setCurrent(target)
        }
    }
    
    func moveToRelativeSliderPosition(_ value: CGFloat) {
        let range = getCurrentChapterScrollRange()
        let total = range.max - range.min
        var amount = total * value
        amount += range.min
        let position = CGPoint(x: 0, y: amount)
        collectionNode.setContentOffset(position, animated: false)
    }

    func onScrollStop() {
        // Update Offset
        updateSliderOffset()
        // Handle Load Prev
        if collectionNode.contentOffset.y <= 0 {
            model.loadPreviousChapter()
        }

        // Do Scroll To
        guard let path = currentPath else {
            return
        }

        // Calculate Current offset for active path
        let attributes = collectionNode.collectionViewLayout.layoutAttributesForItem(at: path)
        if let attributes = attributes {
            let pageOffset = attributes.frame.minY
            let currentOffset = collectionNode.contentOffset.y
            model.activeChapter.requestedPageOffset = currentOffset - pageOffset
        }

        model.didScrollTo(path: path)
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing, model.menuControl.menu {
            model.menuControl.hideMenu()
        }
    }
    
    func getCurrentChapterScrollRange() -> (min: CGFloat, max: CGFloat) {
        // Get Current IP
        guard let path = collectionNode.indexPathForItem(at: currentPoint) else {
            return (min: .zero, max: .zero)
        }
        
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero

        let section = model.sections[path.section]

        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderPage }) {
            let attributes = collectionNode.collectionViewLayout.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minY
            }
        }

        // Get Max knowing that the last index of a section always contains a transition page
        let maxIndex = max(section.endIndex - 2, 0)
        let attributes = collectionNode.collectionViewLayout.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            sectionMaxOffset = attributes.frame.maxY - collectionNode.frame.height
        }
        return (min: sectionMinOffset, max: sectionMaxOffset)
    }
}
