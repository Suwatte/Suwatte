//
//  IV+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//

import Foundation

protocol IVKeyboardNavigationDelegate: NSObject {
    func handleMenuKey()
    func handleLeftKey()
    func handleRightKey()
    func handleChapterListKey()
    func handleBoommarkKey()
    func handleSettingsKey()
    func handleNextChapter()
    func handlePrevChapter()
}
