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
        model
            .getFilteredChapters(onlyDownloads: showOnlyDownloads,
                                 sortMethod: sortKey,
                                 desc: !sortDesc)
    }
}


extension ChapterList {
    func isChapterCompleted(_ chapter: ThreadSafeChapter) -> Bool {
        model.readChapters.contains(chapter.chapterOrderKey)
    }

    func isChapterNew(_ chapter: ThreadSafeChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: ThreadSafeChapter) -> Double? {
        guard let id = model.actionState.chapter?.id, id == chapter.id else {
            return nil
        }
        return model.actionState.marker?.progress
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

        let chapters = model.chapterListChapters
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[0 ... idx]
        selections.formUnion(sub)
    }

    func selectBelow() {
        if selections.isEmpty { return }

        let chapters = model.chapterListChapters
        let target = selections.first

        guard let target, let idx = chapters.firstIndex(of: target) else { return }

        let sub = chapters[idx...]
        selections.formUnion(sub)
    }

    func selectAll() {
        let cs = model.chapterListChapters
        selections = Set(cs)
    }

    func deselectAll() {
        selections.removeAll()
    }

    func fillRange() {
        if selections.isEmpty { return }

        let cs = model.chapterListChapters

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
        let cs = model.chapterListChapters
        selections = Set(cs.filter { !selections.contains($0) })
    }

    func markAsRead() {
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor()
            await actor.bulkMarkChapters(for: id, chapters: chapters)
        }
        deselectAll()
        didMark()
    }

    func markAsUnread() {
        let id = model.STTIDPair
        let chapters = Array(selections)
        Task {
            let actor = await RealmActor()
            await actor.bulkMarkChapters(for: id, chapters: chapters, markAsRead: false)
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

    func clearChapterData() {
        let ids = selections.map(\.id)
        Task {
            let actor = await RealmActor()
            await actor.resetChapterData(for: ids)
        }
        deselectAll()
    }

    func didMark() { // This is called before the notification is delivered to for model `readChapters` property to update
        let identifier = model.identifier
        Task {
            let actor = await RealmActor()
            let maxRead = await actor
                .getContentMarker(for: identifier)?
                .readChapters
                .max()
            let progress = DSKCommon.TrackProgressUpdate(chapter: maxRead, volume: nil) // TODO: Probably Want to get the volume here
            await actor.updateTrackProgress(for: identifier, progress: progress)
        }
    }
}
