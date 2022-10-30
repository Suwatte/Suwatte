//
//  Vertical+TransitionNode.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import UIKit
import AsyncDisplayKit
import Kingfisher
import SwiftUI

fileprivate typealias Controller = VerticalViewer.Controller


extension Controller {
    class TransitionNode: ASCellNode {
        var transition: ReaderView.Transition
        let display = ASDisplayNode()
        weak var delegate: VerticalViewer.Controller?
        
        init(transition: ReaderView.Transition) {
            self.transition = transition
            super.init()
            self.automaticallyManagesSubnodes = true
            self.backgroundColor = .clear
            display.setViewBlock {
                let view = UIHostingController(rootView: ReaderView.ChapterTransitionView(transition: transition)).view!
                view.backgroundColor = .clear
                return view
            }
        }
        
        override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
            ASRatioLayoutSpec(ratio: 1.5, child: display)
        }
        
        override func didEnterDisplayState() {
            super.didEnterDisplayState()
            delegate?.handleChapterPreload(at: indexPath)
        }
    }
}
