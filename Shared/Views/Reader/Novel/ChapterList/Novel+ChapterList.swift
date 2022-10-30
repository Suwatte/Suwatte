//
//  Novel+ChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-01.
//

import SwiftUI

extension NovelReaderView {
    struct ChapterSheet: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ChapterListTile(chapter: model.activeChapter.chapter.toStored(), isCompleted: false, isNewChapter: false)
                    } header: {
                        Text("Currently Reading")
                    }

                    Section {
                        ForEach(model.chapterList, id: \.hashValue) { chapter in
                            Button { didSelect(chapter) } label: {
                                ChapterListTile(chapter: chapter.toStored(), isCompleted: false, isNewChapter: false)
                            }
                            .listRowBackground(model.activeChapter.chapter._id == chapter._id ? Color.accentColor.opacity(0.05) : nil)
                            .id(chapter._id)
                        }
                    } header: {
                        Text("Chapter List")
                    }
                }
                .onAppear {
                    proxy.scrollTo(model.activeChapter.chapter._id, anchor: .center)
                }
            }
        }
    }
}

extension NovelReaderView.ChapterSheet {
    func didSelect(_ chapter: ThreadSafeChapter) {
        model.menuControl.toggleChapterList()

        if model.activeChapter.chapter._id == chapter._id {
            return
        }
        model.resetToChapter(chapter)
    }
}

extension NovelReaderView.ViewModel {
    func resetToChapter(_ chapter: ThreadSafeChapter) {
        activeChapter = .init(chapter: chapter)
        readerChapterList.removeAll()
        sections.removeAll()
        readerChapterList.append(activeChapter)
        Task { @MainActor in
            await self.loadChapter(chapter, asNextChapter: false)
        }
    }
}
