//
//  IV+TransitionCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit
import SwiftUI


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

        func configure(_ data: ReaderTransition) {
            if #available(iOS 16.0, *) {
                contentConfiguration = UIHostingConfiguration {
                    ReaderTransitionView(transition: data)
                }
            } else {
                // Fallback on earlier versions
                view = UIHostingController(rootView: ReaderTransitionView(transition: data)).view

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
