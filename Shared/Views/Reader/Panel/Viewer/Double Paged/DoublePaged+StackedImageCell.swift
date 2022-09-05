//
//  DoublePaged+StackedImageCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-04.
//

import UIKit

extension DoublePagedViewer {
    class StackedImageCell: UICollectionViewCell {
        static var identifier: String = "StackedImageCell"

        var stackView: UIStackView?
        var scrollView: ZoomingScrollView?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
            for pageView in stackView?.arrangedSubviews ?? [] {
                guard let pageView = pageView as? DoublePagedViewer.DImageView else {
                    continue
                }
                pageView.imageView.kf.cancelDownloadTask()
                pageView.imageView.image = nil
                pageView.interactions.removeAll()
                pageView.removeFromSuperview()
                stackView?.removeArrangedSubview(pageView)
                pageView.lm = nil
//                pageView.progressView = nil
                pageView.subscriptions.removeAll()
            }
            stackView?.removeFromSuperview()
            stackView = nil
            super.prepareForReuse()
        }

        func configure(for stackedPage: DoublePagedViewer.Controller.StackedPage) {
            setupScrollView()

            setUpStackView()

            let readingLeftToRight = Preferences.standard.readingLeftToRight

            for page in readingLeftToRight ? stackedPage.pages : stackedPage.pages.reversed() {
                guard let page = page as? ReaderView.Page else {
                    continue
                }
                let pageView = DoublePagedViewer.DImageView()

                pageView.backgroundColor = .clear
                pageView.page = page
                pageView.translatesAutoresizingMaskIntoConstraints = false
                stackView?.addArrangedSubview(pageView)
            }

            setupConstraints()
        }

        func setupScrollView() {
            scrollView = ZoomingScrollView(frame: UIScreen.main.bounds)
        }

        func setUpStackView() {
            stackView = nil
            stackView = UIStackView(frame: scrollView!.frame)
            stackView?.axis = .horizontal
            stackView?.distribution = .fillEqually
            stackView?.backgroundColor = .clear
            scrollView?.target = stackView
        }

        func setupConstraints() {
            guard let scrollView = scrollView else {
                return
            }
            addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            ])
        }

        func setImages() {
            for pageView in stackView?.arrangedSubviews ?? [] {
                guard let pageView = pageView as? DoublePagedViewer.DImageView else {
                    continue
                }
                pageView.setImage()
            }
            scrollView?.addGestures()
        }

        func cancelImages() {
            for pageView in stackView?.arrangedSubviews ?? [] {
                guard let pageView = pageView as? DoublePagedViewer.DImageView else {
                    continue
                }
                pageView.imageView.kf.cancelDownloadTask()
            }
        }

        override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
            return layoutAttributes
        }
    }
}
