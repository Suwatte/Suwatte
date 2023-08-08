//
//  PagedCoordinator+Setup.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import Foundation

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    func setupCollectionView() {
        addTapGestures()
        configureDataSource()
        setReadingOrder()
        listen()
        
    }
    
    func initialLoad() async {
        guard let key = await model.loadState.keys.first else {
            Logger.shared.warn("ChapterState is empty")
            return
        }
        _ = await load(key)
        
        let path: IndexPath = .init(item: 1, section: 0)
        
        await MainActor.run {
            lastIndexPath = path
            updateChapterScrollRange()
            collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: false)
            collectionView.isHidden = false
        }
    }
}
