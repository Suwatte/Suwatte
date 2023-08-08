//
//  PagedCoordinator+Keyboard.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//

import Foundation


fileprivate typealias Coordinator = PagedImageViewer.Coordinator


extension Coordinator: IVKeyboardNavigationDelegate {
    func handleMenuKey() {
        Task { @MainActor in
            model.control.toggleMenu()
        }
        
    }
    
    func handleLeftKey() {
        moveToPage(next: false)
    }
    
    func handleRightKey() {
        moveToPage()
    }
    
    func handleChapterListKey() {
        Task { @MainActor in
            model.control.toggleChapterList()
        }
    }
    
    func handleBoommarkKey() {
        
    }
    
    func handleSettingsKey() {
        Task { @MainActor in
            model.control.toggleSettings()
        }
    }
    
    func handleNextChapter() {
        
    }
    
    func handlePrevChapter() {
        
    }
    
        
}
