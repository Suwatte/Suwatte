//
//  WebtoonController+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func subscribeAll() {
        subToSliderPublisher()
        subToScrubEventPublisher()
        subToAutoScrollPublisher()
        subToPagePaddingPublisher()
    }
}

// MARK: Slider

extension Controller {
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
                self?.onScrollStop()
            }
            .store(in: &subscriptions)
    }

    func subToAutoScrollPublisher() {
        PanelPublisher
            .shared
            .autoScrollDidStart
            .sink { [weak self] state in
                if state {
                    self?.requestAutoPlay()
                } else {
                    self?.cancelAutoScroll()
                }
            }
            .store(in: &subscriptions)
    }

    func subToPagePaddingPublisher() {
        // Padding
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { keyPath in
                keyPath == \Preferences.VerticalPagePadding ||
                    keyPath == \Preferences.verticalPagePaddingAmount
            }
            .sink { [weak self] _ in
                (self?.collectionNode.view.collectionViewLayout as? VImageViewerLayout)?
                    .updateSpacing()
                self?.collectionNode.view.collectionViewLayout.invalidateLayout()
                self?.collectionNode.view.setNeedsLayout()
            }
            .store(in: &subscriptions)
    }
}
