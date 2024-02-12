//
//  CPVM+ActionState.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func setActionState(_ safetyCheck: Bool = false) async {
        let state = await calculateActionState(safetyCheck)
        await animate { [weak self] in
            self?.actionState = state
        }
    }

    func calculateActionState(_ safetyCheck: Bool) async -> ActionState {
        let chapters = Array(getCurrentStatement().filtered.reversed())

        guard !chapters.isEmpty else {
            return .init(state: .none)
        }

        let actor = await RealmActor.shared()

        let marker = await actor
            .getFrozenContentMarker(for: identifier)

        _ = STTHelpers.getReadingMode(for: identifier) // To Update Reading Mode

        func getStateAtIndex(state: ProgressState, marker: ActionState.Marker? = nil, index: Int) -> ActionState {
            let chapter = ChapterManager.getPreferredChapter(matching: index, for: chapters)
            if let chapter {
                return .init(state: state,
                             chapter: chapter,
                             marker: marker)
            } else {
                return getEarliestChapterState()
            }
        }

        func getEarliestChapterState(state: ProgressState = .start) -> ActionState {
            getStateAtIndex(state: state, index: 0)
        }

        func getLatestChapterState() -> ActionState {
            getStateAtIndex(state: .reRead, index: chapters.endIndex - 1)
        }

        guard let marker else {
            if let state = resolveSourceProgressStateAsActionState(chapters: chapters) {
                return state
            }

            return getEarliestChapterState()
        }

        // `calculateActionState` gets called twice. First After Chapters are loaded & after syncing is complete
        // It should return the current action state if the max read chapter was not changed after syncing
        // TODO: Make this not rely on order key
        if safetyCheck, let currentRead = actionState.chapter?.chapterOrderKey,
           let maxRead = marker.maxReadChapterKey, maxRead <= currentRead
        {
            return actionState
        }

        if let sourceStateLastRead = sourceProgressState?.currentReadingState?.readDate,
           let markerDate = marker.dateRead, sourceStateLastRead > markerDate,
           let state = resolveSourceProgressStateAsActionState(chapters: chapters)
        {
            return state
        }

        guard let chapterRef = marker.currentChapter else {
            // Marker Exists but there is not reference to the chapter
            let maxReadChapterKey = marker.maxReadChapterKey

            // Check the max read chapter and use this instead
            guard let maxReadChapterKey else {
                // No Maximum Read Chapter, meaning marker exists without any reference or read chapers, point to first chapter instead
                return getEarliestChapterState()
            }

            // Get the next chapter available after our current max read
            guard let targetIndex = chapters.lastIndex(where: { $0.chapterOrderKey > maxReadChapterKey }) else {
                // if targetIndex is nil, there is no chapter greater than our current maximum read. So reread the max available

                if content.status == .COMPLETED {
                    return getEarliestChapterState(state: .restart) // Restart First
                } else {
                    return getLatestChapterState() // Reread Last
                }
            }

            let state = getStateAtIndex(state: .upNext, index: targetIndex)
            return state
        }

        // Fix edge case where the chapter we want has been deleted/removed, get the matching available chapter
        var correctedChapterId = chapterRef.id
        if !chapters.contains(where: { $0.id == chapterRef.id }),
           let chapter = chapters.last(where: { $0.chapterOrderKey >= chapterRef.chapterOrderKey })
        {
            correctedChapterId = chapter.id
        }

        let targetIndex = chapters
            .firstIndex(where: { $0.id == correctedChapterId })

        guard let targetIndex else {
            return getEarliestChapterState()
        }

        // Marker Exists, Chapter has not been completed, resume
        if !marker.isCompleted {
            let asMarker = ActionState.Marker(progress: marker.progress ?? 0.0, date: marker.dateRead)
            return getStateAtIndex(state: .resume, marker: asMarker, index: targetIndex)
        }

        // Chapter is Completed, Handle Next Chapter
        let next = ChapterManager.getChapter(after: true, index: targetIndex, chapters: chapters)

        // Next Chapter is Available
        if let next {
            return .init(state: .upNext, chapter: next)
        }

        // Title is marked as completed, give option to restart
        if content.status == .COMPLETED {
            return getEarliestChapterState(state: .restart)
        }

        return getLatestChapterState()
    }

    private func resolveSourceProgressStateAsActionState(chapters: [ThreadSafeChapter]) -> ActionState? {
        guard currentChapterSection == sourceID else { return nil }
        guard let state = sourceProgressState?.currentReadingState,
              let currentIndex = chapters.firstIndex(where: { $0.chapterId == state.chapterId })
        else {
            return nil
        }

        if state.progress == 1 {
            if let target = ChapterManager.getChapter(after: true, index: currentIndex, chapters: chapters) { // Completed, Point to Next
                return .init(state: .upNext, chapter: target)
            } else { // There is no next, reread
                return nil
            }

        } else if let target = ChapterManager.getPreferredChapter(matching: currentIndex, for: chapters) {
            // Update Progress in db
            Task.detached {
                let actor = await RealmActor.shared()
                await actor.updateContentProgress(chapter: target,
                                                  lastPageRead: state.page,
                                                  totalPageCount: Int(Double(state.page) / state.progress))
            }
            return .init(state: .resume, chapter: target, marker: .init(progress: state.progress, date: state.readDate))
        }

        return nil
    }
}

enum ChapterManager {
    static func getChapter<T: Collection<ThreadSafeChapter>>(after: Bool, index: Int, chapters: T) -> ThreadSafeChapter? {
        let current = chapters.getOrNil(index as! T.Index)
        guard let current else { return nil }

        let inc_dec = after ? 1 : -1
        let nextIndex = index + inc_dec

        let target = chapters.getOrNil(nextIndex as! T.Index)
        guard let target else { return nil }

        guard target.number != current.number else {
            return getChapter(after: after, index: nextIndex, chapters: chapters)
        }

        return Self.getPreferredChapter(matching: nextIndex, for: chapters)
    }

    /// Get Chapters
    static func getPreferredChapter<T: Collection<ThreadSafeChapter>>(matching index: Int, for chapters: T) -> ThreadSafeChapter? {
        var options: [ThreadSafeChapter] = []

        var counter = index
        let chapter = chapters.getOrNil(index as! T.Index)
        guard let chapter else { return nil }

        // check below
        while counter >= 0 {
            guard let target = chapters.getOrNil(counter as! T.Index), chapter.number == target.number else { break }
            options.append(target)
            counter -= 1
        }

        // Reset count
        counter = index

        // check above
        while counter >= 0 {
            guard let target = chapters.getOrNil(counter as! T.Index), chapter.number == target.number else { break }
            options.append(target)
            counter += 1
        }

        let titleOrder = STTHelpers.getChapterHighPriorityOrder(for: chapter.STTContentIdentifier)
        let sourceOrder = STTHelpers.getChapterPriorityMap(for: chapter.sourceId)

        func getTitleOrder(_ chapter: ThreadSafeChapter) -> Int {
            (chapter.providers ?? [])
                .map { titleOrder.reversed().firstIndex(of: $0.id) ?? -1 }
                .max() ?? -1
        }

        func getSourceOrder(_ chapter: ThreadSafeChapter) -> Int {
            (chapter.providers ?? [])
                .map { sourceOrder[$0.id]?.rawValue ?? ChapterProviderPriority.default.rawValue }
                .max() ?? -1
        }

        let preferredOption = options
            .sorted { lhs, rhs in
                let lhsTO = getTitleOrder(lhs)
                let lhsSO = getSourceOrder(lhs)

                let rhsTO = getTitleOrder(rhs)
                let rhsSO = getSourceOrder(rhs)
                return (lhsTO, lhsSO) > (rhsTO, rhsSO)
            }
            .first

        return preferredOption ?? chapter
    }
}
