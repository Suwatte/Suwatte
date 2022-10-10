//
//  Vertical+Zoom.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import UIKit
import AsyncDisplayKit
import Kingfisher
import SwiftUI

fileprivate typealias Controller = VerticalViewer.AsyncController

extension Controller: ZoomingViewController, ZoomableHostDelegate, ZoomHandlerDelegate {

    


    func cellTappedAt(point: CGPoint, frame: CGRect, path: IndexPath) {
        guard let node = collectionNode.nodeForItem(at: path) as? Controller.ImageNode, let image = node.imageNode.image else {
            return
        }
        selectedIndexPath = path
        let page = VerticalZoomableView()
        page.image = image
        page.location = point
        page.rect = frame
        page.hostDelegate = self
        model.IN_ZOOM_VIEW = true

        navigationController?.pushViewController(page, animated: true)
    }

    func zoomingBackgroundView(for _: ZoomTransitioningDelegate) -> UIView? {
        return nil
    }
    
    func zoomingImageView(for transition: ZoomTransitioningDelegate) -> UIView? {
        guard let path = selectedIndexPath, let node = collectionNode.nodeForItem(at: path) as? Controller.ImageNode else {
            return nil
        }
        
        return node.view
    }
    
    func zoomingImage(for transition: ZoomTransitioningDelegate) -> UIImage? {
        guard let path = selectedIndexPath, let node = collectionNode.nodeForItem(at: path) as? Controller.ImageNode else {
            return nil
        }
        
        return node.imageNode.image
    }
}