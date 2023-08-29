//
//  ChapterList+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import SwiftUI


extension ChapterList {
    
    @ViewBuilder
    func MenuView(for chapter: ThreadSafeChapter, completed: Bool, status: DownloadStatus?) -> some View {
        Button {
            let id = model.STTIDPair
            Task {
                let actor = await RealmActor.shared()
                await actor.bulkMarkChapters(for: id,
                                             chapters: [chapter],
                                             markAsRead: !completed)
            }
            didMark()
        } label: {
            Label(completed ? "Mark as Unread" : "Mark as Read", systemImage: completed ? "eye.slash.circle" : "eye.circle")
        }
        Menu("Mark Below") {
            Button { mark(chapter: chapter, read: true, above: false) } label: {
                Label("As Read", systemImage: "eye.circle")
            }

            Button { mark(chapter: chapter, read: false, above: false) } label: {
                Label("As Unread", systemImage: "eye.slash.circle")
            }
        }
        DownloadView(status, chapter.id)
        ProviderView(chapter)
    }
}
