//
//  Reader+TransitionCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-30.
//

import SwiftUI
import UIKit

extension ReaderView {
    class TransitionCell: UICollectionViewCell {
        static var identifier: String = "PagedTransitionCell"
        var view: UIView?
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            view?.removeFromSuperview()
        }

        func configure(_ data: ReaderView.Transition) {
            view = UIHostingController(rootView: ReaderView.ChapterTransitionView(transition: data)).view

            guard let view = view else {
                return
            }
            addSubview(view)
            backgroundColor = .clear
            view.backgroundColor = .clear
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
            ])
        }
    }
}
