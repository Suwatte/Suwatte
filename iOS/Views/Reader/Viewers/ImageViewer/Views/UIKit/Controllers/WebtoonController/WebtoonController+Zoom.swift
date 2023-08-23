//
//  WebtoonController+Zoom.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import SwiftUI
import UIKit

private typealias Controller = WebtoonController

extension Controller: ZoomingViewController, ZoomableHostDelegate, ZoomHandlerDelegate {
    func cellTappedAt(point: CGPoint, frame: CGRect, path: IndexPath) {
        guard let node = collectionNode.nodeForItem(at: path) as? ImageNode,
              let image = node.image
        else {
            return
        }
        currentZoomingIndexPath = path
        let page = VerticalZoomableView()
        page.image = image
        page.location = point
        page.rect = frame
        page.hostDelegate = self
        isZooming = true

        navigationController?.pushViewController(page, animated: true)
    }

    func zoomingBackgroundView(for _: ZoomTransitioningDelegate) -> UIView? {
        return nil
    }

    func zoomingImageView(for _: ZoomTransitioningDelegate) -> UIView? {
        guard let path = currentZoomingIndexPath,
              let node = collectionNode.nodeForItem(at: path) as? ImageNode
        else {
            return nil
        }

        return node.view
    }

    func zoomingImage(for _: ZoomTransitioningDelegate) -> UIImage? {
        guard let path = currentZoomingIndexPath,
              let node = collectionNode.nodeForItem(at: path) as? ImageNode
        else {
            return nil
        }

        return node.image
    }
}
