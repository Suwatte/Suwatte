//
//  Paged+Controller.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import UIKit


final class TController: UICollectionViewController {
    
    internal var preRotationPath: IndexPath?
    weak var keyboardNavigationDelegate: IVKeyboardNavigationDelegate?
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        preRotationPath = collectionView.currentPath
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }


    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    
    
    override var keyCommands: [UIKeyCommand]? {
        let commands: [UIKeyCommand] = [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeftKey)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRightKey)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleRightKey)),

            UIKeyCommand(input: "M", modifierFlags: [], action: #selector(handleMenuKey)),
            UIKeyCommand(input: "C", modifierFlags: [], action: #selector(handleChapterListKey)),
            UIKeyCommand(input: "B", modifierFlags: [], action: #selector(handleBoommarkKey)),
            UIKeyCommand(input: "S", modifierFlags: [], action: #selector(handleSettingsKey)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: .shift, action: #selector(handlePrevChapter)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: .shift, action: #selector(handleNextChapter)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleCloseKey)),

        ]
        
        // Reference: https://stackoverflow.com/a/70219437
        commands.forEach { $0.wantsPriorityOverSystemBehavior = true }
        
        return commands
    }
    
    @objc func handleMenuKey() {
        keyboardNavigationDelegate?.handleMenuKey()
    }
    
    @objc func handleLeftKey() {
        keyboardNavigationDelegate?.handleLeftKey()
    }
    
    @objc func handleRightKey() {
        keyboardNavigationDelegate?.handleRightKey()
    }
    
    @objc func handleChapterListKey() {
        keyboardNavigationDelegate?.handleChapterListKey()
    }
    
    @objc func handleBoommarkKey() {
        keyboardNavigationDelegate?.handleBoommarkKey()
    }
    
    @objc func handleSettingsKey() {
        keyboardNavigationDelegate?.handleSettingsKey()
    }
    
    @objc func handleNextChapter() {
        keyboardNavigationDelegate?.handleNextChapter()
    }
    
    @objc func handlePrevChapter() {
        keyboardNavigationDelegate?.handlePrevChapter()
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
