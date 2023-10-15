//
//  PagingController+Combine.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import Foundation

private typealias Controller = IVPagingController

extension Controller {
    func subscribeAll() {
        subToSplitPagePublisher()
        subToReadingDirectionPublisher()
        subToSliderPublisher()
        subToScrubEventPublisher()
    }
}

// MARK: State

extension Controller {
    func subToSplitPagePublisher() {
        // Listens for when a page is marked to be split
        guard readingMode.isHorizontalPager else { return }
        PanelPublisher
            .shared
            .willSplitPage
            .sink { page in
                Task { @MainActor [weak self] in
                    self?.split(page)
                }
            }
            .store(in: &subscriptions)

        PanelPublisher
            .shared
            .didChangeSplitMode
            .sink {
                Task { [weak self] in
                    await self?.reload(removeSplits: !Preferences.standard.splitWidePages)
                }
            }
            .store(in: &subscriptions)
    }

    func subToReadingDirectionPublisher() {
        guard readingMode.isHorizontalPager else { return }
        PanelPublisher
            .shared
            .didChangeHorizontalDirection
            .sink { _ in
                Task { @MainActor [weak self] in
                    if let layout = self?.collectionView.collectionViewLayout as? HImageViewerLayout, let mode = self?.model.readingMode {
                        layout.readingMode = mode
                    }
                    self?.setReadingOrder()
                    self?.collectionView.collectionViewLayout.invalidateLayout()
                }
            }
            .store(in: &subscriptions)
    }

    func subToSliderPublisher() {
        PanelPublisher
            .shared
            .sliderPct
            .sink { [weak self] value in
                self?.handleSliderPositionChange(value)
            }
            .store(in: &subscriptions)
    }

    func subToScrubEventPublisher() {
        PanelPublisher
            .shared
            .didEndScrubbing
            .sink { [weak self] in
                self?.setScrollToCurrentIndex()
                self?.onScrollStop()
            }
            .store(in: &subscriptions)
    }
}
