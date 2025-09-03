//
//  ChapterList+Methods.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation
import SwiftUI

extension ChapterList {
    func doFilter() {
        let prepped = model.getCurrentStatement().filtered
        guard !prepped.isEmpty else { return }
        Task {
            let sortedAndPruned = await model.getSortedChapters(prepped, onlyDownloaded: showOnlyDownloads, method: sortKey, descending: !sortDesc)
            await animate {
                chapters = sortedAndPruned
            }
        }
    }
}

extension ChapterList {
    func isChapterCompleted(_ chapter: ThreadSafeChapter) -> Bool {
        guard let marker = model.readChapters[chapter.STTContentIdentifier]?[chapter.id] else {
            return false
        }

        return marker.isCompleted
    }

    func isChapterNew(_ chapter: ThreadSafeChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: ThreadSafeChapter) -> Double? {
        guard let marker = model.readChapters[chapter.STTContentIdentifier]?[chapter.id] else {
            return nil
        }

        return marker.progress
    }

    func getDownload(_ chapter: ThreadSafeChapter) -> DownloadStatus? {
        model.downloads[chapter.id]
    }
}

extension ChapterList {
    func mark(chapter: ThreadSafeChapter, read: Bool, above: Bool) {
        selections.removeAll()
        selections.insert(chapter)
        if above {
            selectAbove()
        } else {
            selectBelow()
        }
        selections.remove(chapter)
        if read {
            markAsRead()
        } else {
            markAsUnread()
        }
    }

    func selectAbove() {
        if selections.isEmpty { return }

        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[0 ... idx]
        selections.formUnion(sub)
    }

    func selectBelow() {
        if selections.isEmpty { return }

        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[idx...]
        selections.formUnion(sub)
    }

    func selectAll() {
        let cs = chapters
        selections = Set(cs)
    }

    func deselectAll() {
        selections.removeAll()
    }

    func fillRange() {
        if selections.isEmpty { return }

        let cs = chapters

        var indexes = [Int]()

        for c in selections {
            if let index = cs.firstIndex(of: c) {
                indexes.append(index)
            }
        }
        indexes.sort()
        //
        let start = indexes.first!
        let end = indexes.last!
        //
        selections = Set(cs[start ... end])
    }

    func invertSelection() {
        let cs = chapters
        selections = Set(cs.filter { !selections.contains($0) })
    }

    func markAsRead() {
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor.shared()
            await actor.markChapters(for: id, chapters: chapters)
            didMark()
        }
        deselectAll()
    }

    func markAsUnread() {
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor.shared()
            await actor.markChapters(for: id, chapters: chapters, markAsRead: false)
        }
        deselectAll()
    }

    func addToDownloadQueue() {
        let ids = Array(selections).map(\.id)
        Task {
            await SDM.shared.add(chapters: ids)
        }
        deselectAll()
    }

    func removeDownload() {
        let ids = Array(selections).map(\.id)
        Task {
            await SDM.shared.cancel(ids: ids)
        }
        deselectAll()
    }

    func didMark() { // This is called before the notification is delivered to for model `readChapters` property to update
        let identifier = model.STTIDPair
        Task {
            let actor = await RealmActor.shared()
            let maxRead = await actor.getMaxReadKey(for: identifier)
            if maxRead == 0 {
                return
            }

            let (volume, number) = ThreadSafeChapter.vnPair(from: maxRead)
            let progress = DSKCommon.TrackProgressUpdate(chapter: number, volume: volume)
            await actor.updateTrackProgress(for: identifier.id, progress: progress)
        }
    }
}
