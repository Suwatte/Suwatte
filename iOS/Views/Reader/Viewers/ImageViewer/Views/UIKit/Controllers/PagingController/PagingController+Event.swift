//
//  PagingController+Event.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit

private typealias Controller = IVPagingController

extension Controller {
    func didChangePage(_ item: PanelViewerItem) {
        let chapter = item.chapter
        if !model.isCurrentlyReading(chapter) {
            didChapterChange(to: chapter)
        }
        switch item {
        case let .page(page):
            let target = page.secondaryPage ?? page.page
            model.updateViewerState(with: target)
            didReadPage(target)

            // Trigger page window management for large chapters
            Task { [weak self] in
                await self?.managePageWindow(currentPage: target)
            }
        case let .transition(transition):
            model.updateViewerState(with: transition)
            didCompleteChapter(chapter)
            if transition.to == nil {
                model.showMenu()
                STTHelpers.triggerHaptic()
            }
        }
    }

    func didChapterChange(to chapter: ThreadSafeChapter) {
        // Update Scrub Range
        currentChapterRange = getScrollRange()
        model.updateViewerStateChapter(chapter)
    }

    func canMark(chapter: ThreadSafeChapter) -> Bool {
        let prefs = Preferences.standard
        return !prefs.incognitoMode && !prefs.disabledHistorySources.contains(chapter.sourceId)
    }

    func didCompleteChapter(_ chapter: ThreadSafeChapter) {
        guard canMark(chapter: chapter) else { return }
        // Update in Database
        Task {
            let actor = await RealmActor.shared()
            await actor.didCompleteChapter(chapter: chapter)
        }

        // Update in Source
        Task {
            guard let source = await DSK.shared.getSource(id: chapter.sourceId),
                  source.intents.chapterEventHandler else { return }
            do {
                try await source.onChapterRead(contentId: chapter.contentId,
                                               chapterId: chapter.chapterId)
            } catch {
                Logger.shared.error(error, source.id)
            }
        }

        // Update on Trackers
        let isInternalSource = STTHelpers
            .isInternalSource(chapter.sourceId)
        guard !isInternalSource else { return }
        Task {
            let actor = await RealmActor.shared()
            let progress = DSKCommon
                .TrackProgressUpdate(chapter: chapter.number,
                                     volume: chapter.volume)
            await actor
                .updateTrackProgress(for: chapter.STTContentIdentifier,
                                     progress: progress,
                                     ignoreTrackerProgress: false)
        }
    }

    func didReadPage(_ page: ReaderPage) {
        guard canMark(chapter: page.chapter) else { return }

        // Update Local DB Marker
        Task {
            let actor = await RealmActor.shared()
            await actor.updateContentProgress(chapter: page.chapter,
                                              lastPageRead: page.number,
                                              totalPageCount: page.chapterPageCount)
            await actor.addPageToStatistics()
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

    /// Manage page window for large chapters to reduce memory usage
    /// For large chapters (200+ pages), aggressively clean image cache for distant pages
    func managePageWindow(currentPage: ReaderPage) async {
        // Only apply for large chapters (more than 100 pages)
        guard currentPage.chapterPageCount > 100 else { return }

        let windowSize = Preferences.standard.readerPageWindowSize
        let currentIndex = currentPage.index

        // More aggressive image cache cleanup for large chapters
        await MainActor.run {
            // Keep only 30% of image cache for large chapters
            let targetCost = ImageCache.shared.totalCost * 3 / 10
            ImageCache.shared.trim(toCost: targetCost)

            Logger.shared.log("Large chapter (\(currentPage.chapterPageCount) pages): Page \(currentIndex+1), trimmed image cache", "PagingController")
        }
    }
}
