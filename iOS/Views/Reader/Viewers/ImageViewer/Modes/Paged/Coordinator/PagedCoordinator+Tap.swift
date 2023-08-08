//
//  PagedCoordinator+Tap.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit

fileprivate typealias Coordinator = PagedImageViewer.Coordinator

// MARK: - Tap Gestures
extension Coordinator {
    
    func addTapGestures() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }
    
    @objc fileprivate func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: controller.view)
        handleNavigation(at: location)
    }

    @objc fileprivate func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }
}


extension Coordinator {
    func handleNavigation(at point: CGPoint) {
        let tapToNavigate = UserDefaults.standard.bool(forKey: STTKeys.TapSidesToNavigate)
        
        guard tapToNavigate else {
            // TODO: Open Menu
            return
        }
        
        var navigator: ReaderNavigation.Modes?

        let vertical = Preferences.standard.isReadingVertically
        let key = UserDefaults.standard.integer(forKey: vertical ? STTKeys.VerticalNavigator : STTKeys.PagedNavigator)
        navigator = .init(rawValue: key)
        guard let navigator = navigator else {
            // Open Menu
            return
        }
        
        var action = navigator.mode.action(for: point, ofSize: collectionView.frame.size)

        if Preferences.standard.invertTapSidesToNavigate {
            if action == .LEFT { action = .RIGHT }
            else if action == .RIGHT { action = .LEFT }
        }
        
        switch action {
        case .MENU:
            Task { @MainActor in
                model.control.toggleMenu()
            }
            break
        case .LEFT:
            Task { @MainActor in
                model.control.hideMenu()
            }
            moveToPage(next: false)
            
        case .RIGHT:
            Task { @MainActor in
                model.control.hideMenu()
            }
            moveToPage()
        }
    }
    
    func moveToPage(next: Bool = true) {
        let width = collectionView.frame.width
        let offset = !next ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width
        
        let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

        guard let path else { return }
        collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
    }
}
