//
//  ReaderView+ChapterSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-09.
//

import SwiftUI

extension ReaderView {
    struct ChapterSheet: View {
        @EnvironmentObject var model: ReaderView.ViewModel
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

extension ReaderView.ChapterSheet {
    func didSelect(_ chapter: ThreadSafeChapter) {
        if model.activeChapter.chapter._id == chapter._id {
            return
        }
        model.menuControl.toggleChapterList()
        model.resetToChapter(chapter)
    }
}
