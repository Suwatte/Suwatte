//
//  WebtoonController+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit
fileprivate typealias Controller = WebtoonController

extension Controller {
    func subscribeAll() {
        subToSliderPublisher()
        subToScrubEventPublisher()
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
}
