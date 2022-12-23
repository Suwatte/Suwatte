//
//  VerticalPaged+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-22.
//

import Combine
import UIKit


// MARK: Subscriptions

extension VerticalPager.Controller {
    func listen() {
        // MARK: Reload
        model.reloadPublisher.sink { [weak self] in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
                self?.collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .centeredVertically, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Insert
        model.insertPublisher.sink { [unowned self] section in

            Task { @MainActor in

                // Next Chapter Logic
                let data = model.sections[section]
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? VerticalContentOffsetPreservingLayout
                layout?.isInsertingCellsToTop = section == 0 && model.sections.count != 0

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)

        // MARK: Slider
        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = CGPoint(x: 0, y: slider.current)

                if let path = collectionView.indexPathForItem(at: position), let item = model.sections[path.section][path.item] as? ReaderView.Page {
                    model.scrubbingPageNumber = item.index + 1
                }

                collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: Navigation Publisher
        model.navigationPublisher.sink { [unowned self] action in
            let isPreviousTap = action == .LEFT
            let height = collectionView.frame.height
            let offset = isPreviousTap ? collectionView.currentPoint.y - height : collectionView.currentPoint.y + height

            let path = collectionView.indexPathForItem(at: .init(x:0 , y: offset))

            if let path = path {
                collectionView.scrollToItem(at: path, at: .centeredVertically, animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Did End Scrubbing
        model.scrubEndPublisher.sink { [weak self] in
            guard let currentPath = self?.currentPath else {
                return
            }
            self?.collectionView.scrollToItem(at: currentPath, at: .centeredVertically, animated: true)
        }
        .store(in: &subscriptions)
        
        Preferences.standard.preferencesChangedSubject
            .filter { $0 == \Preferences.imageInteractions }
            .sink { [unowned self] _ in
                enableInteractions = Preferences.standard.imageInteractions
                collectionView.reloadData() // TODO: Check for more performant alternative
            }
            .store(in: &subscriptions)
    }
}
