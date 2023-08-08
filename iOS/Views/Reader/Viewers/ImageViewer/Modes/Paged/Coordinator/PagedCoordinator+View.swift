//
//  PagedCoordinator+View.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import UIKit


fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    func split(_ page: PanelPage) {
        var snapshot = dataSource.snapshot()
        
        var secondary = page
        secondary.isSecondaryPage = true
        print(secondary.hashValue, page.hashValue)
        snapshot.insertItems([.page(secondary)], afterItem: .page(page))
        
        let s = snapshot
        Task { @MainActor in
            dataSource.apply(s, animatingDifferences: false)
        }
    }
}


extension Coordinator {
    func setReadingOrder() {
        if Preferences.standard.readingLeftToRight {
            collectionView.transform = .identity
        } else {
            collectionView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }
}
