//
//  VerticalPaged+Cell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-22.
//

import UIKit
import Combine
extension VerticalPager.Controller {
    class ImageCell: UICollectionViewCell {
        static var identifier: String = "VerticalPagerCell"
        var pageView: ContentView?
        var subscriptions = Set<AnyCancellable>()

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
            subscriptions.removeAll()
            pageView?.scrollView.reset()
            pageView?.removeFromSuperview()
            pageView = nil
            super.prepareForReuse()
        }

        func initializePage(page: ReaderView.Page) {
            pageView = ContentView()

            guard let pageView else {
                return
            }

            pageView.backgroundColor = .clear
            pageView.page = page
            pageView.setupViews()
            subscribe()
            
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
        
        func subscribe() {
            Preferences
                .standard
                .preferencesChangedSubject
                .filter { changedKeyPath in
                    changedKeyPath == \Preferences.downsampleImages ||
                        changedKeyPath == \Preferences.cropWhiteSpaces
                }
                .sink { [unowned self] _ in
                    pageView?.imageView.image = nil
                    setImage()
                }
                .store(in: &subscriptions)
        }
    }
}
