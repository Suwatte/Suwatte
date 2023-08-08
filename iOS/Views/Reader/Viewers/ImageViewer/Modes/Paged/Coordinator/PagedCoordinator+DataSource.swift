//
//  PagedCoordinator+DataSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import Foundation
import UIKit


fileprivate typealias Coordinator = PagedImageViewer.Coordinator
extension Coordinator {

    func configureDataSource() {
        let ImageCellRegistration = UICollectionView.CellRegistration<PagedViewerImageCell, PanelPage> { cell, indexPath, data in
            cell.set(page: data, delegate: self)
            cell.setImage()
        }
        
        let TransitionCellRegistration = UICollectionView.CellRegistration<TransitionCell, ReaderTransition> { cell, indexPath, data in
            cell.configure(data)
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            collectionView, indexPath, item -> UICollectionViewCell in
            switch item {
            case .page(let page):
                return collectionView.dequeueConfiguredReusableCell(using: ImageCellRegistration, for: indexPath, item: page)
            case .transition(let transition):
                return collectionView.dequeueConfiguredReusableCell(using: TransitionCellRegistration, for: indexPath, item: transition)
            }
        }
    }
}
