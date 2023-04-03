//
//  DoublePage+Scroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-15.
//

import UIKit

extension DoublePagedViewer.Controller {
    func getCurrentChapterScrollRange() -> (min: CGFloat, max: CGFloat) {
        // Get Current IP
        guard let path = currentPath else {
            return (min: .zero, max: .zero)
        }

        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero

        let stack = getStack(for: path.section)

        // Get Min
        if let minIndex = stack.firstIndex(where: { $0.primary is ReaderPage }) {
            let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))
            if let attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }

        // Get Max knowing that the last index of a section always contains a transition page
        let maxIndex = max(stack.endIndex - 2, 0)
        let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes {
            sectionMaxOffset = attributes.frame.minX
        }
        return (min: sectionMinOffset, max: sectionMaxOffset)
    }

    func updateSliderOffset() {
        let range = getCurrentChapterScrollRange()
        let total = range.max - range.min
        var current = collectionView.contentOffset.x - range.min
        current = max(0, current)
        current = min(range.max, current)
        let target = current / total
        DispatchQueue.main.async { [weak self] in
            self?.model.slider.setCurrent(target)
        }
    }

    func getPositionRelativeTo(_ value: CGFloat) -> CGPoint {
        let range = getCurrentChapterScrollRange()
        let total = range.max - range.min
        var amount = total * value
        amount += range.min
        let position = CGPoint(x: amount, y: 0)
        return position
    }
}

extension DoublePagedViewer.Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.x)
    }

    func onUserDidScroll(to _: CGFloat) {
        // Update Offset
        if !model.slider.isScrubbing {
            updateSliderOffset()
        }
    }
}

// MARK: DID STOP SCROLL

extension DoublePagedViewer.Controller {
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
        model.menuControl.hideMenu()
        applyPendingUpdates()
        // Handle Load Prev
        if collectionView.contentOffset.x <= 0 {
            model.loadPreviousChapter()
        }
        // Recalculate Scrollable Range
        updateSliderOffset()

        // Do Scroll To
        guard let path = currentPath else {
            return
        }

        if path.section != lastViewedSection {
            STTHelpers.triggerHaptic()
            lastViewedSection = path.section
        }

        let item = getStack(for: path.section)
            .get(index: path.item)

        let page = item?.secondary ?? item?.primary
        let index = model.sections[path.section].firstIndex(where: { $0 === page })
        if let index {
            model.didScrollTo(path: .init(item: index, section: path.section))
        }

        model.scrubbingPageNumber = nil
        model.activeChapter.requestedPageOffset = nil
    }
}
