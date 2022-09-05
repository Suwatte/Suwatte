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

        var pageView: ReaderPageView?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
            pageView?.imageView.kf.cancelDownloadTask()
            pageView?.downloadTask?.cancel()
            pageView?.imageView.image = nil
            pageView?.imageView.interactions.removeAll()
            pageView?.imageView.removeFromSuperview()
            pageView?.subscriptions.removeAll()
            pageView?.scrollView.reset()
            pageView?.removeFromSuperview()
            pageView = nil
            super.prepareForReuse()
        }

        func initializePage(page: ReaderView.Page) {
            pageView = ReaderPageView()

            guard let pageView = pageView else {
                return
            }

            pageView.backgroundColor = .clear
            pageView.page = page
            pageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pageView)

            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: topAnchor),
                pageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                pageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                pageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            ])
        }

        func setImage() {
            pageView?.setImage()
        }

        override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
            return layoutAttributes
        }
    }
}
