//
//  WebtoonController+Event.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import Foundation
private typealias Controller = WebtoonController

extension Controller {
    func didChangePage(_ item: PanelViewerItem, indexPath: IndexPath) {
        let chapter = item.chapter
        if !model.isCurrentlyReading(chapter) {
            didChapterChange(to: chapter)
        }
        switch item {
        case let .page(page):
            let target = page.secondaryPage ?? page.page
            model.updateViewerState(with: target)
            didReadPage(target, path: indexPath)
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
        STTHelpers.triggerHaptic()
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

    func didReadPage(_ page: ReaderPage, path: IndexPath) {
        guard canMark(chapter: page.chapter) else { return }
        let pixelsSinceLastStop = abs(offset - lastStoppedScrollPosition)
        let pageOffset = calculateCurrentOffset(of: path)

        // is last page, has completed 95% of the chapter, mark as completed
        if page.isLastPage, let pageOffset, pageOffset >= 0.95 {
            didCompleteChapter(page.chapter)
            return
        }

        // Update Local DB Marker
        Task {
            let actor = await RealmActor.shared()
            await actor.updateContentProgress(chapter: page.chapter,
                                              lastPageRead: page.number,
                                              totalPageCount: page.chapterPageCount,
                                              lastPageOffsetPCT: pageOffset)
            if pixelsSinceLastStop != 0 {
                await actor.addOffsetToStatistics(pixelsSinceLastStop)
                await MainActor.run { [weak self] in
                    self?.lastStoppedScrollPosition = self?.offset ?? 0
                }
            }
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

    func calculateCurrentOffset(of path: IndexPath) -> Double? {
        guard let frame = frameOfItem(at: path) else { return nil }
        let size = frame.size
        let pageTop = frame.minY
        let currentOffset = offset
        let pageOffset = Double(currentOffset - pageTop) / size.height
        return pageOffset
    }
}
