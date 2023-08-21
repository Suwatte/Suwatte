//
//  WebtoonController+Event.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import Foundation
fileprivate typealias Controller = WebtoonController


extension Controller {
    
    func didChangePage(_ item: PanelViewerItem) {
        switch item {
            case .page(let page):
                if model.viewerState.chapter != page.page.chapter {
                    didChapterChange(from: model.viewerState.chapter, to: page.page.chapter)
                }
                model.viewerState.page = page.page.index + 1
                model.viewerState.pageCount = page.page.chapterPageCount
                // TODO: DB Actions
            case .transition(let transition):
                break
        }
    }
    
    
    
    func didChapterChange(from: ThreadSafeChapter, to chapter: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
        model.viewerState.chapter = chapter
    }
    
    func didCompleteChapter(_ chapter: ThreadSafeChapter) {
        STTHelpers.triggerHaptic()

    }
    
    @MainActor
    func loadPrevChapter() async {
        guard let current = pathAtCenterOfScreen, // Current Index
              let chapter = dataSource.itemIdentifier(for: current)?.chapter, // Current Chapter
              let currentReadingIndex = await dataCache.chapters.firstIndex(of: chapter), // Index Relative to ChapterList
              currentReadingIndex != 0, // Is not the first chapter
              let next = await dataCache.chapters.getOrNil(currentReadingIndex - 1), // Next Chapter in List
              model.loadState[next] == nil else { return } // is not already loading/loaded
        
        await loadAtHead(next)
    }
}
