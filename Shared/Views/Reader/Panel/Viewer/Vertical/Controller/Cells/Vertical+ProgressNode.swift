//
//  Vertical+ProgressNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import Kingfisher
import SwiftUI
import UIKit

private typealias Controller = VerticalViewer.Controller

extension Controller {
    class ProgressNode: ASCellNode {
        var model: ReaderView.ProgressObject
        init(model: ReaderView.ProgressObject) {
            self.model = model
            super.init()
            setViewBlock {
                UIHostingController(rootView: ReaderView.PageProgressView(model: model)).view!
            }
        }
    }
}
