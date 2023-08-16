//
//  PagingController+Scroll.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit

fileprivate typealias Controller = IVPagingController


// MARK: Did Scroll
extension Controller {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset)
    }
    
    
    func onUserDidScroll(to point: CGPoint) {
        
        let pos = isVertical ? point.y : point.x
        
        if pos < 0 {
            didTriggerBackTick = true
            return
        }
        
        let difference = abs(pos - lastKnownScrollPosition)
        guard difference >= scrollPositionUpdateThreshold else { return }
        lastKnownScrollPosition = pos
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Only real-time update when the user is not scrubbing & the menu is being shown
            guard !model.slider.isScrubbing && model.control.menu else { return }
//            setScrollPCT(for: pos)
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
        let currentPath = collectionView.pathAtCenterOfScreen
        
        model.hideMenu()

        
        if didTriggerBackTick {
            Task { [weak self] in
                await self?.loadPrevChapter()
            }
            didTriggerBackTick = false
        }
        
        guard let currentPath else { return }
        
        if currentPath.section != lastIndexPath.section {
            STTHelpers.triggerHaptic()
            let prev = dataSource.itemIdentifier(for: lastIndexPath)?.chapter
            let next = dataSource.itemIdentifier(for: currentPath)?.chapter
            guard let prev, let next else { return }
            didChapterChange(from: prev, to: next)
        } else {
            guard currentPath.item != lastIndexPath.item, let page = dataSource.itemIdentifier(for: currentPath) else { return }
            didChangePage(page)
        }
                
        lastIndexPath = currentPath
        
        Task { @MainActor [weak self] in
            guard let self, !self.model.control.menu else { return }
            self.setScrollPCT(for: self.collectionView.currentPoint.x)
        }
        
    }
}

// MARK: Slider
extension Controller {
    func updateChapterScrollRange() {
        self.currentChapterRange = getScrollRange()
    }
    
    func scrollToPosition(for pct: Double) -> CGFloat {
        let total = currentChapterRange.max - currentChapterRange.min
        var amount = total * pct
        amount += currentChapterRange.min
        return amount
    }
    
    func setScrollPCT(for offset: CGFloat) {
        let contentOffset = isVertical ? collectionView.contentOffset.y : collectionView.contentOffset.x
        let total = currentChapterRange.max - currentChapterRange.min
        var current = contentOffset - currentChapterRange.min
        current = max(0, current)
        current = min(currentChapterRange.max, current)
        let target = Double(current / total)
        
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
        
        return .init(x: isVertical ? 0: value,
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
              case .page(let page) = dataSource.itemIdentifier(for: path) else {
            return
        }
        
        model.viewerState.page = page.page.number
    }
    
    func getScrollRange() -> (min: CGFloat, max: CGFloat) {
        let def : (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = collectionView.currentPath else {
            return def
        }
        let snapshot = dataSource.snapshot()
        let item = dataSource.itemIdentifier(for: path)
        guard let item else { return def }
        let section = snapshot.itemIdentifiers(inSection: item.chapter.id)
        
        let minIndex = section.firstIndex(where: \.isPage) // O(1)
        let maxIndex = max(section.endIndex - 2, 0)
        
        // Get Min
        if let minIndex  {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))
            
            if let attributes = attributes {
                sectionMinOffset = attributes.frame.minX
            }
        }
        
        // Get Max
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes = attributes {
            sectionMaxOffset = attributes.frame.minX
        }
        
        return (min: sectionMinOffset, max: sectionMaxOffset)
    }

}
