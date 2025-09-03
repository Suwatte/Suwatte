//
//  PagingController+Gesture.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-21.
//

import UIKit

private typealias Controller = IVPagingController

// MARK: - Tap Gestures

extension Controller {
    func addTapGestures() {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        tapGR.require(toFail: doubleTapGR)
        collectionView.addGestureRecognizer(doubleTapGR)
        collectionView.addGestureRecognizer(tapGR)
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: view)
        handleNavigation(at: location)
    }

    @objc private func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }
}

// MARK: Handle Navigation

extension Controller {
    func handleNavigation(at point: CGPoint) {
        let preferences = Preferences.standard
        let tapToNavigate = preferences.tapSidesToNavigate

        guard tapToNavigate,!model.control.menu else {
            model.toggleMenu()
            return
        }

        var navigator: ReaderNavigation.Modes?

        let isVertical = model.readingMode.isVertical

        navigator = isVertical ? preferences.verticalNavigator : preferences.horizontalNavigator

        guard let navigator else {
            model.toggleMenu()
            return
        }
        var action = navigator.mode.action(for: point, ofSize: view.frame.size)

        func invertAction(_ action: inout ReaderNavigation.NavigationType) {
            if action == .LEFT { action = .RIGHT }
            else if action == .RIGHT { action = .LEFT }
        }

        if isInverted {
            invertAction(&action)
        }

        if preferences.invertTapSidesToNavigate {
            invertAction(&action)
        }

        switch action {
        case .MENU:
            model.toggleMenu()

        case .LEFT:
            model.hideMenu()
            moveToPage(next: false)

        case .RIGHT:
            model.hideMenu()
            moveToPage()
        }
    }
}
