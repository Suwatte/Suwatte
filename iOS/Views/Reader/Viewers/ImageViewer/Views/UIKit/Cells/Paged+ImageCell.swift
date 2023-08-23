//
//  Paged+ImageCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit

protocol CancellableImageCell: NSObject {
    func cancelTasks()
}

class PagedViewerImageCell: UICollectionViewCell, CancellableImageCell {
    var pageView: PagedViewerImageHolder?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pageView?.cancel()
        pageView?.reset()
        pageView?.imageView.image = nil
        pageView?.removeFromSuperview()
        pageView = nil
        NSLayoutConstraint.deactivate(pageViewContraints)
        pageViewContraints.removeAll()
    }

    func set(page: PanelPage, delegate: UIContextMenuInteractionDelegate?) {
        // Initialize
        pageView = PagedViewerImageHolder(page: page, frame: frame)
        pageView?.delegate = delegate

        guard let pageView else { fatalError("Holder Cannot Be Nil") }
        pageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageView)
        pageView.setup()

        // Add Context Menu Interaction
        if Preferences.standard.imageInteractions, let delegate {
            pageView.addImageInteraction(UIContextMenuInteraction(delegate: delegate))
        }

        // AutoLayout
        pageViewContraints = [
            pageView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            pageView.heightAnchor.constraint(equalTo: contentView.heightAnchor),
            pageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ]
        NSLayoutConstraint.activate(pageViewContraints)
        pageView.subscribe()
    }

    var pageViewContraints: [NSLayoutConstraint] = []

    func setImage() {
        pageView?.load()
    }

    func cancelTasks() {
        pageView?.cancel()
    }
}
