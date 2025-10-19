//
//  WebtoonController+Gesture.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func addGestures() {
        let tapGR = UITapGestureRecognizer(target: self,
                                           action: #selector(handleTap(_:)))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gesture:)))

        collectionNode.view.addGestureRecognizer(longPressGesture)
        collectionNode.view.addGestureRecognizer(tapGR)
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        cancelAutoScroll()
        guard let sender else {
            return
        }

        let location = sender.location(in: navigationController?.view)
        handleNavigation(at: location)
    }

    @objc func handleLongPress(gesture _: UILongPressGestureRecognizer) {
        cancelAutoScroll()
        let interaction = UIContextMenuInteraction(delegate: self)
        navigationController?
            .view
            .addInteraction(interaction)
    }
}
