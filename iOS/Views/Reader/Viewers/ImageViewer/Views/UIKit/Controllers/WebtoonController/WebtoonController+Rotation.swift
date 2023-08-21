//
//  WebtoonController+Rotation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit
fileprivate typealias Controller = WebtoonController


extension Controller: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let preRotationPath, let preRotationOffset else {
            return proposedContentOffset
        }
        let maxY = collectionNode.view.contentSize.height
        collectionNode.scrollToItem(at: preRotationPath, at: .top, animated: false)
        var current = collectionNode.contentOffset
        current.y = min(maxY, max(offset + preRotationOffset, 0))
        self.preRotationPath = nil
        self.preRotationOffset = nil
        
        return current
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        defer {
            collectionNode.collectionViewLayout.invalidateLayout()
        }
        preRotationPath = pathAtCenterOfScreen
        preRotationOffset = 0
        guard let preRotationPath else { return }
        let minY = frameOfItem(at: preRotationPath)?.minY
        guard let minY else { return }
        preRotationOffset = offset - minY
    }
}
