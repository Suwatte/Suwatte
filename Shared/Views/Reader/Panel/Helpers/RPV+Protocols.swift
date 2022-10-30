//
//  ReaderView+Protocals.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-20.
//

import UIKit
import AsyncDisplayKit

protocol ZoomHandlerDelegate: UIViewController {
    func cellTappedAt(point: CGPoint, frame: CGRect, path: IndexPath)
}

protocol ZoomableHostDelegate: NSObject {
    var collectionNode: ASCollectionNode { get }
    var selectedIndexPath: IndexPath! { get set }
}

protocol VerticalImageScrollDelegate: AnyObject {
    func didEndZooming(_ scale: CGFloat, _ points: (inWindow: CGPoint?, inView: CGPoint?)?, _ view: UIView?)
}

// MARK: Size Preserving Layout

class HorizontalContentSizePreservingFlowLayout: UICollectionViewFlowLayout {
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

class NovelOffsetPreservingLayout: UICollectionViewFlowLayout {
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
}

class VerticalContentOffsetPreservingLayout: UICollectionViewFlowLayout {
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
}
