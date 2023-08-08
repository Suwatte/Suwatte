//
//  Paged+Coordinator.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit
import SwiftUI
import Combine

extension PagedImageViewer {
    
    final class Coordinator: NSObject {
        var controller: PagedViewerController! {
            didSet {
                setupCollectionView()
            }
        }
        
        var model: IVViewModel! {
            didSet {
                Task {
                    await initialLoad()
                }
                
            }
        }
        
        var dataCache: IVDataCache {
            model.dataCache
        }
                
        var collectionView: UICollectionView {
            controller.collectionView
        }
        
        internal var dataSource: UICollectionViewDiffableDataSource<String, PanelViewerItem>!
        internal var subscriptions = Set<AnyCancellable>()
        internal var lastIndexPath: IndexPath = .init(item: 0, section: 0)
        internal var currentChapterRange: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
        internal var didTriggerBackTick = false
    }
}

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

extension Coordinator {
    func load(_ chapterID: String) async {
        let pages = await dataCache.prepare(chapterID)
        guard let pages else {
            return
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([chapterID])
        snapshot.appendItems(pages, toSection: chapterID)
        let s = snapshot
        await MainActor.run {
            dataSource.apply(s, animatingDifferences: false)
        }
    }
    
    func load(_ chapter: ThreadSafeChapter) async {
        do {
            await model.updateChapterState(chapter.id, state: .loading)
            try await dataCache.load(for: chapter)
            await load(chapter.id)
        } catch {
            Logger.shared.error(error)
            await model.updateChapterState(chapter.id, state: .failed(error))
            return
        }
    }
    
    func loadAtHead(_ chapter: ThreadSafeChapter) async {
        await model.updateChapterState(chapter.id, state: .loading)
        
        do {
            try await dataCache.load(for: chapter)
            let pages = await dataCache.prepare(chapter.id)
            var snapshot = dataSource.snapshot()
            let head = snapshot.sectionIdentifiers.first
            guard let pages, let head else {
                return
            }
            
            
            snapshot.insertSections([chapter.id], beforeSection: head)
            snapshot.appendItems(pages, toSection: chapter.id)
            let s = snapshot
            await MainActor.run {
                preparingToInsertAtHead()
                dataSource.apply(s, animatingDifferences: false)
            }
        } catch {
            Logger.shared.error(error)
            await model.updateChapterState(chapter.id, state: .failed(error))
            ToastManager.shared.error("Failed to load chapter.")
        }

    }
    
    func preparingToInsertAtHead() {
        let layout = collectionView.collectionViewLayout as? HImageViewerLayout
        layout?.isInsertingCellsToTop = true
    }
}
