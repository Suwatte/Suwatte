//
//  IV+TransitionCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI
import UIKit

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
            .margins(.all, 0)

        } else {
            // Fallback on earlier versions
            let controller = UIHostingController(rootView: ReaderTransitionView(transition: data))

            let view = controller.view

            guard let view = view else {
                return
            }
            addSubview(view)
            backgroundColor = .clear
            view.backgroundColor = .clear

            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: contentView.topAnchor),
                view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ])
        }
    }
}
