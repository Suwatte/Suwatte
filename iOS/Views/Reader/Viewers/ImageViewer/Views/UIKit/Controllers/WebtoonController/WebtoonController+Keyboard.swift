//
//  WebtoonController+Keyboard.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-03.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    override var keyCommands: [UIKeyCommand]? {
        let commands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleDownKey)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleUpKey)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleDownKey)),
            UIKeyCommand(input: "P", modifierFlags: [], action: #selector(handleAutoPlayKey)),
            UIKeyCommand(input: "M", modifierFlags: [], action: #selector(handleMenuKey)),
            UIKeyCommand(input: "C", modifierFlags: [], action: #selector(handleChapterListKey)),
            UIKeyCommand(input: "S", modifierFlags: [], action: #selector(handleSettingsKey)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleCloseKey)),
        ]

        // Reference: https://stackoverflow.com/a/70219437
        commands.forEach { $0.wantsPriorityOverSystemBehavior = true }

        return commands
    }

    @objc func handleMenuKey() {
        model.toggleMenu()
    }

    @objc func handleUpKey() {
        moveToPage(next: false)
    }

    @objc func handleDownKey() {
        moveToPage()
    }

    @objc func handleChapterListKey() {
        model.toggleChapterList()
    }

    @objc func handleSettingsKey() {
        model.toggleSettings()
    }

    @objc func handleAutoPlayKey() {
        guard UserDefaults.standard.bool(forKey: STTKeys.VerticalAutoScroll) else {
            return
        }
        requestAutoPlay()
    }

    @objc func handleCloseKey() {
        if var topController = KEY_WINDOW?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.dismiss(animated: true)
        }
    }
}
