//
//  PagingController+Scroll.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit

private typealias Controller = IVPagingController

// MARK: Did Scroll

extension Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset)
    }

    func onUserDidScroll(to point: CGPoint) {
        let pos = isVertical ? point.y : point.x

        if pos < 0, !didTriggerBackTick {
            didTriggerBackTick = true
            return
        }

        let difference = abs(pos - lastKnownScrollPosition)
        guard difference >= scrollPositionUpdateThreshold else { return }
        lastKnownScrollPosition = pos
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Only real-time update when the user is not scrubbing & the menu is being shown
            guard !model.slider.isScrubbing, model.control.menu else { return }
            if Preferences.standard.readerHideMenuOnSwipe {
                model.hideMenu()
            }
            setScrollPCT()
        }
    }
}

// MARK: Did Stop Scrolling

extension Controller {
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
        if didTriggerBackTick {
            Task { [weak self] in
                await self?.loadPrevChapter()
            }
            didTriggerBackTick = false
        }
        let currentPath = collectionView.pathAtCenterOfScreen
        guard let currentPath else { return }

        guard let page = dataSource.itemIdentifier(for: currentPath) else { return }
        if lastIndexPath.item != currentPath.item {
            didChangePage(page)
            lastIndexPath = currentPath
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.setScrollPCT()
        }
    }
}

// MARK: Slider

extension Controller {
    func updateChapterScrollRange() {
        currentChapterRange = getScrollRange()
    }

    func scrollToPosition(for pct: Double) -> CGFloat {
        let total = currentChapterRange.max - currentChapterRange.min
        var amount = total * pct
        amount += currentChapterRange.min
        return amount
    }

    func setScrollPCT() {
        let contentOffset = offset
        let total = currentChapterRange.max - currentChapterRange.min
        var current = contentOffset - currentChapterRange.min
        current = max(0, current)
        current = min(currentChapterRange.max, current)
        let target = Double(current) / Double(total)

        Task { @MainActor [weak self] in
            self?.model.slider.current = target
        }
    }

    func setScrollToCurrentIndex() {
        guard let path = collectionView.pathAtCenterOfScreen else { return }
        collectionView.scrollToItem(at: path, at: isVertical ? .centeredVertically : .centeredHorizontally, animated: true)
    }
}

// MARK: Proposed Content Offset

extension Controller {
    override func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let path = preRotationPath else {
            return proposedContentOffset
        }

        let frame = collectionView.layoutAttributesForItem(at: path)?.frame

        let value = isVertical ? frame?.minY : frame?.minX

        guard let value else {
            return proposedContentOffset
        }

        // Reset
        preRotationPath = nil

        return .init(x: isVertical ? 0 : value,
                     y: isVertical ? value : 0)
    }
}

extension Controller {
    func handleSliderPositionChange(_ value: Double) {
        guard model.slider.isScrubbing else {
            return
        }
        let position = scrollToPosition(for: value)
        let point = CGPoint(x: !isVertical ? position : 0,
                            y: isVertical ? position : 0)

        defer {
            collectionView.setContentOffset(point, animated: false)
        }
        guard let path = collectionView.indexPathForItem(at: point),
              case let .page(page) = dataSource.itemIdentifier(for: path)
        else {
            return
        }

        model.viewerState.page = page.page.number
    }

    func getScrollRange() -> (min: CGFloat, max: CGFloat) {
        let def: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.pathAtCenterOfScreen else {
            return def
        }
        let snapshot = dataSource.snapshot()
        let item = dataSource.itemIdentifier(for: path)
        guard let item else { return def }
        let section = snapshot.itemIdentifiers(inSection: item.chapter.id)

        let minIndex = section.firstIndex(where: \.isPage) // O(1)
        let maxIndex = max(section.endIndex - (section.count <= 10 ? 1 : 2), 0)

        // Get Min
        if let minIndex {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes = attributes {
                let frame = attributes.frame
                sectionMinOffset = isVertical ? frame.minY : frame.minX
            }
        }

        // Get Max
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            let frame = attributes.frame
            sectionMaxOffset = isVertical ? frame.minY : frame.minX
        }

        return (min: sectionMinOffset, max: sectionMaxOffset)
    }
}
