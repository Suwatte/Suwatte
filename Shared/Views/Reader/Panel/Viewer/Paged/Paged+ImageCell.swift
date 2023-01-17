//
//  Paged+ImageCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-30.
//

import UIKit

extension PagedViewer {
    class ImageCell: UICollectionViewCell {
        static var identifier: String = "PagedViewerCell"

        var pageView: PagedDisplayHolder?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
            pageView?.reset()
            pageView?.removeFromSuperview()
            pageView = nil
            NSLayoutConstraint.deactivate(pageViewContraints)
            pageViewContraints.removeAll()
            super.prepareForReuse()
        }
        
        func set(page: ReaderPage, delegate: PagerDelegate) {
            // Initialize
            pageView = PagedDisplayHolder()
            pageView?.page = page
            pageView?.delegate = delegate
            guard let pageView else { fatalError("Holder Cannot Be Nil") }
            pageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pageView)
            pageView.setup()

            // Add Context Menu Interaction
            if Preferences.standard.imageInteractions {
                pageView.addImageInteraction(UIContextMenuInteraction(delegate: delegate))
            }
            
            
            // AutoLayout
            pageViewContraints = [
                pageView.widthAnchor.constraint(equalTo: widthAnchor),
                pageView.heightAnchor.constraint(equalTo: heightAnchor),
                pageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                pageView.centerXAnchor.constraint(equalTo: centerXAnchor)
            ]
            NSLayoutConstraint.activate(pageViewContraints)
            pageView.subscribe()
        }
        
        var pageViewContraints : [NSLayoutConstraint] = []

        func setImage() {
            pageView?.load()
        }
        
        
        func cancelTasks() {
            pageView?.cancel()
        }

        override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
            return layoutAttributes
        }
    }
}
