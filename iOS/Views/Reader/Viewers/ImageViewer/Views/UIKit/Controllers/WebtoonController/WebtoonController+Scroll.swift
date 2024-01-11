//
//  WebtoonController+Scroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit
private typealias Controller = WebtoonController

// MARK: Delegate Methods

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

// MARK: Controller Methods

extension Controller {
    func onScrollStop() {
        model.hideMenu()

        // Load Previous Chapter if requested
        if didTriggerBackTick {
            Task { [weak self] in
                await self?.loadPrevChapter()
            }
            didTriggerBackTick = false
        }

        let currentPath = pathAtCenterOfScreen
        guard let currentPath else { return }

        guard let page = dataSource.itemIdentifier(for: currentPath) else { return }
        didChangePage(page, indexPath: currentPath)
        lastIndexPath = currentPath

        guard !model.control.menu else { return }
        Task { @MainActor [weak self] in
            self?.setScrollPCT()
        }
    }

    func onUserDidScroll(to position: CGFloat) {
        // Hide Menu if not scrubbing
        if !model.slider.isScrubbing, model.control.menu {
            Task { @MainActor in
                model.hideMenu()
            }
        }

        // If current offset is lower than 0, user wants to see previous chapter
        if position < 0, !didTriggerBackTick {
            didTriggerBackTick = true
            return
        }

        // Update Last Scroll Position
        let difference = abs(position - lastKnownScrollPosition)
        guard difference >= scrollPositionUpdateThreshold else { return }
        lastKnownScrollPosition = position

        // Only real-time update when the user is not scrubbing & the menu is being shown
        guard !model.slider.isScrubbing, model.control.menu else { return }
        Task { @MainActor [weak self] in
            self?.setScrollPCT()
        }
    }
}
