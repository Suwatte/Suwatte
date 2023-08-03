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

        @State var showLangFlag = false
        @State var showDate = false

        var body: some View {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ChapterListTile(chapter: model.activeChapter.chapter.toStored(),
                                        isCompleted: false,
                                        isNewChapter: false,
                                        isLinked: false,
                                        showLanguageFlag: showLangFlag,
                                        showDate: showDate)
                    } header: {
                        Text("Currently Reading")
                    }

                    Section {
                        ForEach(model.chapterList, id: \.hashValue) { chapter in
                            Button { didSelect(chapter) } label: {
                                ChapterListTile(chapter: chapter.toStored(),
                                                isCompleted: false,
                                                isNewChapter: false,
                                                isLinked: false,
                                                showLanguageFlag: showLangFlag,
                                                showDate: showDate)
                            }
                            .listRowBackground(model.activeChapter.chapter.id == chapter.id ? Color.accentColor.opacity(0.05) : nil)
                            .id(chapter.id)
                        }
                    } header: {
                        Text("Chapter List")
                    }
                }
                .onAppear {
                    proxy.scrollTo(model.activeChapter.chapter.id, anchor: .center)
                }
                .task {
                    await loadSource()
                }
            }
        }
    }
}

extension ReaderView.ChapterSheet {
    func didSelect(_ chapter: ThreadSafeChapter) {
        if model.activeChapter.chapter.id == chapter.id {
            return
        }
        model.menuControl.toggleChapterList()
        model.resetToChapter(chapter)
    }
    
    func loadSource() async {
        let sourceId = model.activeChapter.chapter.sourceId
        if STTHelpers.isInternalSource(sourceId) { return }
        guard let source = await DSK.shared.getSource(id: sourceId) else { return }
        showLangFlag = source.ablityNotDisabled(\.disableLanguageFlags)
        showDate = source.ablityNotDisabled(\.disableChapterDates)
    }
}
