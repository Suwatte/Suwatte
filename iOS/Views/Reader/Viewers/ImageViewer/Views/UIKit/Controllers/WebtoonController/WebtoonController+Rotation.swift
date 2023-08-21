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
        let val = (frameOfItem(at: preRotationPath)?.minY ?? 0) + preRotationOffset
        let corrected = min(maxY, max(val, 0))
        self.preRotationPath = nil
        self.preRotationOffset = nil
        
        return .init(x: 0, y: corrected)
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
