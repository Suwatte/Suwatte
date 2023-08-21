//
//  WebtoonController+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

fileprivate typealias Controller = WebtoonController

extension Controller {
    func captureVisibleRect(of view: UIView) -> UIImage? {
        let offset = collectionNode.contentOffset
        let visibleRect = CGRect(x: offset.x,
                                     y: offset.y,
                                     width: view.bounds.width,
                                     height: view.bounds.height)

        UIGraphicsBeginImageContextWithOptions(visibleRect.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: -visibleRect.origin.x, y: -visibleRect.origin.y)
        view.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    

    

}

extension Controller: UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: { [unowned self] in
            // Create and return a preview for the visible portion of the image
            let previewVC = UIViewController()
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: UIScreen.main.bounds.size))
            imageView.contentMode = .scaleAspectFit
            imageView.image = captureVisibleRect(of: collectionNode.view)
            previewVC.view = imageView
            return previewVC
        }, actionProvider: { suggestedActions in
        
            // Create an action for sharing
                        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { action in
                            // Show system share sheet
                        }
                
                        // Create an action for renaming
                        let rename = UIAction(title: "Rename", image: UIImage(systemName: "square.and.pencil")) { action in
                            // Perform renaming
                        }
                
                        // Here we specify the "destructive" attribute to show that it’s destructive in nature
                        let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { action in
                            // Perform delete
                        }
                
                        // Create and return a UIMenu with all of the actions as children
                        return UIMenu(title: "", children: [share, rename, delete])
        }) // No actions are provided in this case
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        navigationController?.view.removeInteraction(interaction)
    }
    
}


