//
//  Novel+Paged+ContentCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-30.
//

import UIKit

extension NovelReaderView.PagedViewer.Controller {
    class ContentCell: UICollectionViewCell {
        static var identifier: String = "PagedViewerCell"

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepareForReuse() {}
    }
}
