//
//  WebtoonController+Navigation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

fileprivate typealias Controller = WebtoonController

extension Controller {
    internal func handleNavigation(at point: CGPoint) {
        let preferences = Preferences.standard
        let tapToNavigate = preferences.tapSidesToNavigate
        
        guard tapToNavigate else {
            model.toggleMenu()
            return
        }
        
        var navigator: ReaderNavigation.Modes?

        
        navigator = preferences.verticalNavigator
        
        guard let navigator else {
            model.toggleMenu()
            return
        }
        var action = navigator.mode.action(for: point, ofSize: view.frame.size)
        
        if preferences.invertTapSidesToNavigate {
            if action == .LEFT { action = .RIGHT }
            else if action == .RIGHT { action = .LEFT }
        }

        switch action {
        case .MENU:
            model.toggleMenu()
            break
        case .LEFT:
            model.hideMenu()
            moveToPage(next: false)
            
        case .RIGHT:
            model.hideMenu()
            moveToPage()
        }
    }
    
    func moveToPage(next: Bool = true) {
        let range = currentChapterRange
        let multiplier: CGFloat = (next ? 1 : -1)
        let jump = view.frame.height * 0.66 * multiplier
        var newOffset = offset + jump
        let size = contentSize
        newOffset = min(contentSize.height, max(newOffset, 0))
        
        collectionNode
            .setContentOffset(.init(x: 0, y: newOffset), animated: true)
    }
    

}
