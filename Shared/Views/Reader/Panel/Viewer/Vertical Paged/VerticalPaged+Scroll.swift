//
//  VerticalPaged+Scroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-22.
//

import Foundation
import SwiftUI
import UIKit

extension VerticalPager.Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.y)
        isScrolling = true
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing {
            Task { @MainActor in
                model.slider.setCurrent(collectionView.contentOffset.y)
            }
        }
    }

    func calculateCurrentChapterScrollRange() {
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.indexPathForItem(at: collectionView.currentPoint) else {
            return
        }

        let section = model.sections[path.section]

        // Get Min
        if let minIndex = section.firstIndex(where: { $0 is ReaderPage }) {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minY
            }
        }

        // Get Max
        let maxIndex = max(section.endIndex - 2, 0)
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            sectionMaxOffset = attributes.frame.minY
        }

        withAnimation {
            model.slider.setRange(sectionMinOffset, sectionMaxOffset)
        }
    }
}

// MARK: Did Stop Scrolling

extension VerticalPager.Controller {
    override func scrollViewDidEndDecelerating(_: UIScrollView) {
        onScrollStop()
    }

    override func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            return
        }
        onScrollStop()
    }

    override func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        onScrollStop()
    }

    func onScrollStop() {
        isScrolling = false

        model.menuControl.hideMenu()
        // Handle Load Prev
        if collectionView.contentOffset.y <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        calculateCurrentChapterScrollRange()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }
        if path.section != lastViewedSection {
            STTHelpers.triggerHaptic()
            lastViewedSection = path.section
        }
        model.activeChapter.requestedPageOffset = nil
        model.didScrollTo(path: path)
        model.scrubbingPageNumber = nil
    }
}
