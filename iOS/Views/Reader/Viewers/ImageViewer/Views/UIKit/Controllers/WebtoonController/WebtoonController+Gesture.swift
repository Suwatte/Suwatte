//
//  WebtoonController+Gesture.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

fileprivate typealias Controller = WebtoonController

extension Controller {
    
    func addGestures() {
        let tapGR = UITapGestureRecognizer(target: self,
                                           action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self,
                                                 action: #selector(handleDoubleTap(_:)))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gesture:)))
        
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        
        collectionNode.view.addGestureRecognizer(longPressGesture)
        collectionNode.view.addGestureRecognizer(doubleTapGR)
        collectionNode.view.addGestureRecognizer(tapGR)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
//        cancelAutoScroll()
        guard let sender else {
            return
        }

        let location = sender.location(in: navigationController?.view)
        handleNavigation(at: location)
    }

    @objc func handleDoubleTap(_ sender:  UITapGestureRecognizer? = nil) {
        guard let sender else {
            return
        }

        let point = sender.location(in: view)
        let path = collectionNode.indexPathForItem(at: point)
        let node = path.flatMap(collectionNode.nodeForItem(at:)) as? ImageNode
        guard let node, let image = node.image else { return }
        
        print("double tapped")
        // Do Nothing
    }
    
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
        let interaction = UIContextMenuInteraction(delegate: self)
        navigationController?
            .view
            .addInteraction(interaction)
    }
}

