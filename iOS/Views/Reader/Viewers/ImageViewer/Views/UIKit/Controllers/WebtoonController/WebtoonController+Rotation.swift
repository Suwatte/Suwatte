//
//  WebtoonController+Rotation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let preRotationPath, let preRotationOffset else {
            return proposedContentOffset
        }
        let maxY = collectionNode.view.contentSize.height
        collectionNode.scrollToItem(at: preRotationPath, at: .top, animated: false)
        let frame = frameOfItem(at: preRotationPath)?.size
        guard let frame else { return .init(x: 0, y: offset) }
        let additionalOffset = frame.height * preRotationOffset
        var current = collectionNode.contentOffset
        current.y = min(maxY, max(offset + additionalOffset, 0))
        self.preRotationPath = nil
        self.preRotationOffset = nil
        return current
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cancelAutoScroll()
        defer {
            collectionNode.collectionViewLayout.invalidateLayout()
        }
        guard let path = pathAtCenterOfScreen else { return }
        preRotationPath = path
        preRotationOffset = calculateCurrentOffset(of: path).flatMap(CGFloat.init)
    }
}
