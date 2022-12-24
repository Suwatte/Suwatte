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

    func onScrollStop() {
        model.slider.setCurrent(collectionNode.contentOffset.y)
//        isScrolling = false
        // Handle Load Prev
        if collectionNode.contentOffset.y <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

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

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionNode.indexPathForItem(at: currentPoint) else {
            return
        }

        let section = model.sections[path.section]

        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionNode.collectionViewLayout.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minY
            }
        }

        // Get Max
        if let maxIndex = section.lastIndex(where: { $0 is ReaderView.Page }) {
            let attributes = collectionNode.collectionViewLayout.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
            if let attributes = attributes {
                sectionMaxOffset = attributes.frame.maxY - collectionNode.frame.height
            }
        }
        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing, model.menuControl.menu {
            model.menuControl.hideMenu()
        }

        if model.slider.isScrubbing {
            calculateCurrentChapterScrollRange()
        }
    }
}
