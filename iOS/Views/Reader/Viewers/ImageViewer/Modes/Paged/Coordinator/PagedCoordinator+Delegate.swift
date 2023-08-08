//
//  PagedCoordinator+Delegate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import UIKit

extension UICollectionView {
    var currentPoint: CGPoint {
        .init(x: contentOffset.x + frame.midX, y: contentOffset.y + frame.midY)
    }

    var currentPath: IndexPath? {
        indexPathForItem(at: currentPoint)
     }
}

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

// MARK: FlowLayout
extension Coordinator: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}


// MARK: - Did End Displaying
extension Coordinator {
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? PagedViewerImageCell else { return }
        cell.cancelTasks()
    }
}

// MARK: - Will Display
extension Coordinator {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let data = dataSource.itemIdentifier(for:  indexPath)
        
        guard let data else { return }
        
        guard case .page(let page) = data else { return }
        
        let current = page.page.number
        let count = page.page.chapterPageCount
        let chapter = page.page.chapter
        let inPreloadRange = count - current < 5
        
        guard inPreloadRange else { return }
        
        Task {
            await preload(after: chapter)
        }
    }
    
    func preload(after chapter: ThreadSafeChapter) async {
        let index = await dataCache.chapters.firstIndex(of: chapter)
        
        guard let index else { return } // should always pass
        
        let next = await dataCache.chapters.getOrNil(index + 1)
        
        guard let next else { return }
        
        let currentState = await model.loadState[next.id]
        
        guard currentState == nil else { return } // only trigger if the chapter has not been loaded
        
        await load(next)
    }
}
