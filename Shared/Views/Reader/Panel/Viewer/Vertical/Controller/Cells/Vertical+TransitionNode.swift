//
//  Vertical+TransitionNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import AsyncDisplayKit
import SwiftUI
import UIKit

private typealias Controller = VerticalViewer.Controller

extension Controller {
    class TransitionNode: ASCellNode {
        var transition: ReaderView.Transition
        let display = ASDisplayNode()
        weak var delegate: VerticalViewer.Controller?

        init(transition: ReaderView.Transition) {
            self.transition = transition
            super.init()
            automaticallyManagesSubnodes = true
            backgroundColor = .clear
        }

        override func layoutSpecThatFits(_: ASSizeRange) -> ASLayoutSpec {
            ASRatioLayoutSpec(ratio: 1.5, child: display)
        }

        override func didEnterPreloadState() {
            super.didEnterPreloadState()
            if isNodeLoaded {
                return
            }
            display.setViewBlock {
                let view = UIHostingController(rootView: ReaderView.ChapterTransitionView(transition: self.transition)).view!
                view.backgroundColor = .clear
                return view
            }
        }
    }
}
