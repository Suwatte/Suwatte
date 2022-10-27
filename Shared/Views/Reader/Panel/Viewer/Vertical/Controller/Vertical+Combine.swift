//
//  Vertical+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import UIKit
import AsyncDisplayKit
import Kingfisher
import SwiftUI

fileprivate typealias Controller = VerticalViewer.Controller


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
            }
        }.store(in: &subscriptions)
        
        // MARK: Scrub End
        model.scrubEndPublisher.sink { [weak self] in
            self?.onScrollStop()
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
            if slider.isScrubbing {
                let position = CGPoint(x: 0, y: slider.current)
                self?.collectionNode.setContentOffset(position, animated: false)
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
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.forceTransitions ||
                changedKeyPath == \Preferences.imageInteractions
            }.sink { [weak self] _ in
                self?.collectionNode.reloadData()
            }.store(in: &subscriptions)
    }
}

