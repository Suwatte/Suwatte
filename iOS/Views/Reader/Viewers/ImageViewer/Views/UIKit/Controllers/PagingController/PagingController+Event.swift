//
//  PagingController+Event.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit


fileprivate typealias Controller = IVPagingController

extension Controller {
    
    func didChangePage(_ item: PanelViewerItem) {
        let chapter = item.chapter
        if !model.isCurrentlyReading(chapter) {
            didChapterChange(to: chapter)
        }
        switch item {
            case .page(let page):
                let target = page.secondaryPage ?? page.page
                model.updateViewerState(with: target)
                didReadPage(target)
            case .transition(let transition):
                model.updateViewState(with: transition)
                didCompleteChapter(chapter)
        }
    }
    
    func didChapterChange(to chapter: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
        model.changeViewerStateChapter(chapter)
    }
    
    func canMark(chapter: ThreadSafeChapter) -> Bool {
        let prefs = Preferences.standard
        return !prefs.incognitoMode && !prefs.disabledHistorySources.contains(chapter.sourceId)
    }

    
    func didCompleteChapter(_ chapter: ThreadSafeChapter) {
        guard canMark(chapter: chapter) else { return }
        // Update in Database
        Task {
            let actor = await RealmActor()
            await actor.didCompleteChapter(chapter: chapter)
        }
        
        // Update in Source
        Task {
            guard let source = await DSK.shared.getSource(id: chapter.sourceId),
                  source.intents.chapterSyncHandler else { return }
           do {
               try await source.onChapterRead(contentId: chapter.contentId,
                                              chapterId: chapter.chapterId)
           } catch {
               Logger.shared.error(error, source.id)
           }
        }
        
        // Update on Trackers
    }
    
    func didReadPage(_ page: ReaderPage) {
        guard canMark(chapter: page.chapter) else { return }
        
        // Update Local DB Marker
        Task {
            let actor = await RealmActor()
            await actor.updateContentProgress(chapter: page.chapter,
                                              lastPageRead: page.number,
                                              totalPageCount: page.chapterPageCount)
        }
        
        // Update on Source
        let isInternalSource = STTHelpers
            .isInternalSource(page.chapter.sourceId)
        guard !isInternalSource else { return }
        onPageReadTask?.cancel()
        onPageReadTask = Task {
            let chapter = page.chapter
            guard let source = await DSK.shared.getSource(id: chapter.sourceId) else { return }
            do {
                try await source.onPageRead(contentId: chapter.contentId,
                                            chapterId: chapter.chapterId,
                                            page: page.number)
            } catch {
                Logger.shared.error(error, source.id)
            }
        }

    }
    
}
