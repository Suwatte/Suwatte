//
//  PagingController+State.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit


fileprivate typealias Controller = IVPagingController

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
    
    @objc fileprivate func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let sender = sender else {
            return
        }

        let location = sender.location(in: view)
        handleNavigation(at: location)
    }

    @objc fileprivate func handleDoubleTap(_: UITapGestureRecognizer? = nil) {
        // Do Nothing
    }
}

// MARK: Handle Navigation
extension Controller {
    internal func handleNavigation(at point: CGPoint) {
        let preferences = Preferences.standard
        let tapToNavigate = preferences.tapSidesToNavigate
        
        guard tapToNavigate else {
            // TODO: Open Menu
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
    
}

extension Controller {
    
    func didChangePage(_ item: PanelViewerItem) {
        switch item {
            case .page(let page):
                model.viewerState.chapter = page.page.chapter
                model.viewerState.page = page.page.index + 1
                model.viewerState.pageCount = page.page.chapterPageCount
                // TODO: DB Actions
            case .transition(let transition):
                break
        }
    }
    
    func didChapterChange(from: ThreadSafeChapter, to: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
    }
    
    @MainActor
    func loadPrevChapter() async {
        guard let current = collectionView.currentPath, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let currentReadingIndex = await dataCache.chapters.firstIndex(of: chapter), // Index Relative to ChapterList
              currentReadingIndex != 0, // Is not the first chapter
              let next = await dataCache.chapters.getOrNil(currentReadingIndex - 1), // Next Chapter in List
              model.loadState[next] == nil else { return } // is not already loading/loaded
        
        await loadAtHead(next)
    }
}
