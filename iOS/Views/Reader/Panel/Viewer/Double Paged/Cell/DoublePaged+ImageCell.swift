//
//  DoublePaged+ImageCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-15.
//

import Foundation

import UIKit

extension DoublePagedViewer {
    class ImageCell: UICollectionViewCell {
        static var identifier: String = "DoublePagerImageCell"

        var pageView: DoublePagedDisplayHolder?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
//            pageView?.reset()
            pageView?.removeFromSuperview()
            pageView = nil
            NSLayoutConstraint.deactivate(pageViewContraints)
            pageViewContraints.removeAll()
            super.prepareForReuse()
        }

        func set(primary: ReaderPage, secondary: ReaderPage, delegate: DoublePagedViewer.Controller) {
            // Initialize
            pageView = DoublePagedDisplayHolder()
            pageView?.firstPage = primary
            pageView?.secondPage = secondary
            pageView?.delegate = delegate
            guard let pageView else { fatalError("Holder Cannot Be Nil") }
            pageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pageView)
            pageView.setup()
            // AutoLayout
            pageViewContraints = [
                pageView.widthAnchor.constraint(equalTo: widthAnchor),
                pageView.heightAnchor.constraint(equalTo: heightAnchor),
                pageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                pageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ]
            NSLayoutConstraint.activate(pageViewContraints)
//            pageView.subscribe()
        }

        var pageViewContraints: [NSLayoutConstraint] = []

        func setImage() {
            pageView?.load()
        }

        func cancelTasks() {
            pageView?.cancel()
        }
    }
}
