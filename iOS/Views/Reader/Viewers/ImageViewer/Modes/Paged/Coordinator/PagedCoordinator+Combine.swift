//
//  PagedCoordinator+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import Foundation
import Combine

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    func listen() {
        watchSplitPage()
        watchReadingDirection()
    }
}

// MARK: State
extension Coordinator {
    func watchSplitPage() {
        // Listens for when a page is marked to be split
        PanelPublisher
            .shared
            .willSplitPage
            .sink { [weak self] page in
                self?.split(page)
            }
            .store(in: &subscriptions)
        
    }
    
    func watchReadingDirection() {
        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.readingLeftToRight == $0 }
            .sink { [unowned self] _ in
                setReadingOrder()
                Task { @MainActor in
                    collectionView.collectionViewLayout.invalidateLayout()
                }
            }
            .store(in: &subscriptions)
    }
}
