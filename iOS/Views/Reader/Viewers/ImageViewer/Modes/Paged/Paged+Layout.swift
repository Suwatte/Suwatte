//
//  Paged+Layout.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit


class HImageViewerLayout: UICollectionViewFlowLayout {
    
    override init() {
        super.init()
        scrollDirection = .horizontal
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
        sectionInset = UIEdgeInsets.zero
        estimatedItemSize = .zero
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isInsertingCellsToTop: Bool = false {
        didSet {
            if isInsertingCellsToTop {
                contentSizeBeforeInsertingToTop = collectionViewContentSize
            }
        }
    }

    private var contentSizeBeforeInsertingToTop: CGSize?

    override func prepare() {
        if isInsertingCellsToTop {
            if let collectionView = collectionView, let oldContentSize = contentSizeBeforeInsertingToTop {
                UIView.performWithoutAnimation {
                    let newContentSize = self.collectionViewContentSize
                    let contentOffsetX = collectionView.contentOffset.x + (newContentSize.width - oldContentSize.width)
                    let contentOffsetY = collectionView.contentOffset.y + (newContentSize.height - oldContentSize.height)
                    let newOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
                    collectionView.contentOffset = newOffset
                }
            }
            contentSizeBeforeInsertingToTop = nil
            isInsertingCellsToTop = false
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let readingLeftToRight = Preferences.standard.readingLeftToRight

        let layoutAttributes = super.layoutAttributesForElements(in: rect) ?? []
        for attribute in layoutAttributes {
            attribute.transform = readingLeftToRight ? .identity : .init(scaleX: -1, y: 1)
        }

        return layoutAttributes
    }
}

