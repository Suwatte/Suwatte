//
//  WebtoonController+AutoScroll.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-21.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func requestAutoPlay() {
        if timer != nil {
            cancelAutoScroll()
        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    @objc func timerAction() {
        DispatchQueue.main.async {
            let amount = (UIScreen.main.bounds.height / Preferences.standard.verticalAutoScrollSpeed) * 0.15
            let offset = min(self.collectionNode.contentOffset.y + amount, self.contentSize.height - UIScreen.main.bounds.height)

            UIView.animate(withDuration: 0.151, delay: 0, options: [.curveLinear, .allowUserInteraction]) {
                self.collectionNode.contentOffset.y = offset
            } completion: { c in
                if !c { return }
                if self.contentSize.height - self.collectionNode.contentOffset.y - UIScreen.main.bounds.height > amount { return }
                self.cancelAutoScroll()
            }
        }
    }

    func cancelAutoScroll() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
            onScrollStop()
            PanelPublisher.shared.autoScrollDidStop.send()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
