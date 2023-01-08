//
//  Vertical+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import Kingfisher
import SwiftUI
import UIKit

private typealias Controller = VerticalViewer.Controller

extension IndexPath {
    static let origin = IndexPath(item: 0, section: 0)
}

extension Controller {
    func listen() {
        // MARK: Reload

        model.reloadPublisher.sink { [weak self] in
            DispatchQueue.main.async {
                self?.collectionNode.reloadData()
                self?.collectionNode.scrollToItem(at: .origin, at: .top, animated: false)
                self?.updateSliderOffset()
            }
        }.store(in: &subscriptions)

        // MARK: Scrub End

        model.scrubEndPublisher.sink { [weak self] in
            Task { @MainActor in
                self?.onScrollStop()
            }
        }
        .store(in: &subscriptions)

        // MARK: Insert

        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in
                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionNode.collectionViewLayout as? VerticalContentOffsetPreservingLayout
                let topInsertion = section == 0 && model.sections.count != 0
                layout?.isInsertingCellsToTop = topInsertion

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionNode.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionNode.insertSections(set)
                    collectionNode.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)

        // MARK: Slider

        model.$slider.sink { [weak self] slider in
            Task { @MainActor in
                if slider.isScrubbing {
                    self?.moveToRelativeSliderPosition(slider.current)
                }
            }
        }
        .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in
            var currentOffset = collectionNode.contentOffset.y
            let amount = UIScreen.main.bounds.height * 0.66
            switch action {
            case .LEFT: currentOffset -= amount
            case .RIGHT: currentOffset += amount
            default: return
            }
            if action == .LEFT, currentOffset < 0 {
                currentOffset = 0
            } else if action == .RIGHT, currentOffset >= contentSize.height - collectionNode.frame.height {
                currentOffset = contentSize.height - collectionNode.frame.height
            }
            DispatchQueue.main.async {
                self.collectionNode.setContentOffset(.init(x: 0, y: currentOffset), animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Preference Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { $0 == \Preferences.forceTransitions || $0 == \Preferences.imageInteractions }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.collectionNode.reloadData()
                }
            }
            .store(in: &subscriptions)

        Preferences.standard.preferencesChangedSubject
            .filter { $0 == \Preferences.VerticalPagePadding }
            .sink { [weak self] _ in
                Task { @MainActor in
                    let enabled = Preferences.standard.VerticalPagePadding
                    guard let layout = self?.collectionNode.collectionViewLayout as? UICollectionViewFlowLayout else { return }
                    layout.minimumLineSpacing = enabled ? 10 : 0
                    self?.collectionNode.collectionViewLayout.invalidateLayout()
                }
            }
            .store(in: &subscriptions)

        model
            .verticalTimerPublisher
            .sink { [unowned self] in

                if timer != nil {
                    cancelAutoScroll()
                } else {
                    timer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
                    model.autoplayEnabled = true
                }
            }
            .store(in: &subscriptions)
    }
}

extension Controller {
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
            model.autoplayEnabled = false
            model.scrubEndPublisher.send()
        }
    }
}
