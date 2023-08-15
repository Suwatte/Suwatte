//
//  ReaderGateWay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-15.
//

import SwiftUI

struct ReaderGateWay: View {
    var readingMode: ReadingMode = .defaultPanelMode
    var chapterList: [StoredChapter]
    var openTo: StoredChapter
    var pageIndex: Int?
    var title: String?
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
    
    var body: some View {
        Group {
            if readingMode.isPanelMode {
                ImageViewer(initial: .init(chapters: chapterList,
                                           openTo: openTo,
                                           pageIndex: pageIndex,
                                           pageOffset: nil,
                                           title: title ?? ""))
            } else if readingMode == .WEB {
                WebReader(chapter: openTo)
            } else {
                Text("Novel Placeholder")
            }
        }
        .tint(accentColor)
        .accentColor(accentColor)
        .onAppear(perform: StateManager.shared.readerOpenedPublisher.send)
        .onDisappear(perform: StateManager.shared.readerClosedPublisher.send)
    }
}

struct WebReader: View {
    var chapter: StoredChapter
    
    var body: some View {
        NavigationView {
            STTWebView(url: URL(string: chapter.webUrl ?? ""))
                .closeButton()
                .navigationTitle(chapter.displayName)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
