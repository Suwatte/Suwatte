//
//  PagedCoordinator+Scroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import UIKit
import SwiftUI

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    
    func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        
        guard let path = controller.preRotationPath else {
            return proposedContentOffset
        }
        
        let x = collectionView.layoutAttributesForItem(at: path)?.frame.minX
        
        guard let x else {
            return proposedContentOffset
        }
        
        // Reset
        controller.preRotationPath = nil
        
        return .init(x: x, y: 0)
    }
    
}


extension Coordinator {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onUserDidScroll(to: scrollView.contentOffset.x)
    }
    
    
    func onUserDidScroll(to pos: CGFloat) {
        if pos < 0 {
            didTriggerBackTick = true
            return
        }
        
        let difference = abs(pos - lastKnownScrollPosition)
        guard difference >= scrollPositionUpdateThreshold else { return }
        lastKnownScrollPosition = pos
        Task { @MainActor in
            // Only real-time update when the user is not scrubbing & the menu is being shown
            guard !model.slider.isScrubbing && model.control.menu else { return }
            setScrollPCT(for: pos)
        }
        
    }
}

// MARK: Did Stop Scrolling

extension Coordinator {
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
    
    func onScrollStop() {
        let currentPath = collectionView.currentPath
        
        Task { @MainActor in
            model.control.hideMenu()
        }
        
        if didTriggerBackTick {
            Task {
                await loadPrevChapter()
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
        
        Task { @MainActor in
            guard !model.control.menu else { return }
            setScrollPCT(for: collectionView.currentPoint.x)
        }
        
    }
}

// MARK: Slider
extension Coordinator {
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
    
    func updateChapterScrollRange() {
        self.currentChapterRange = getScrollRange()
    }
    
    func scrollToPosition(for pct: Double) {
        let total = currentChapterRange.max - currentChapterRange.min
        var amount = total * pct
        amount += currentChapterRange.min
        
        let positon = CGPoint(x: amount, y: 0)
        collectionView.setContentOffset(positon, animated: false)
    }
    
    func setScrollPCT(for offset: CGFloat) {
        let total = currentChapterRange.max - currentChapterRange.min
        var current = collectionView.contentOffset.x - currentChapterRange.min
        current = max(0, current)
        current = min(currentChapterRange.max, current)
        let target = Double(current / total)
        Task { @MainActor in
            withAnimation {
                model.slider.current = target
            }
        }
    }
    
    func setScrollToCurrentIndex() {
        guard let path = collectionView.currentPath else { return }
        collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
    }
    
}
