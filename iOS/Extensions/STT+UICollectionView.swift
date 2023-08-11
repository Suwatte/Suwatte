//
//  STT+UICollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import UIKit

extension UICollectionView {
    var currentPoint: CGPoint {
        .init(x: contentOffset.x + frame.midX, y: contentOffset.y + frame.midY)
    }

    var currentPath: IndexPath? {
        indexPathsForVisibleItems.first
     }
    
    var pathAtCenterOfScreen: IndexPath? {
        indexPathForItem(at: currentPoint)
    }
    
}

