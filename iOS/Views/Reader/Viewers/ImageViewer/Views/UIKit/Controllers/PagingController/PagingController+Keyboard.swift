//
//  PagingController+Keyboard.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-03.
//

import UIKit

private typealias Controller = IVPagingController

extension Controller {
    override var keyCommands: [UIKeyCommand]? {
        let commands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeftKey)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRightKey)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleRightKey)),
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

    @objc func handleLeftKey() {
        moveToPage(next: isInverted)
    }

    @objc func handleRightKey() {
        moveToPage(next: !isInverted)
    }

    @objc func handleChapterListKey() {
        model.toggleChapterList()
    }

    @objc func handleSettingsKey() {
        model.toggleSettings()
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
