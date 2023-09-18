//
//  ReaderGateWay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-15.
//

import SwiftUI

struct ReaderGateWay: View {
    var title: String
    var readingMode: ReadingMode = .defaultPanelMode
    var chapterList: [ThreadSafeChapter]
    var openTo: ThreadSafeChapter
    var pageIndex: Int?
    var pageOffset: Double?
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

    var body: some View {
        ZStack {
            if readingMode.isPanelMode {
                ImageViewer(initial: .init(chapters: chapterList,
                                           openTo: openTo,
                                           pageIndex: pageIndex,
                                           pageOffset: pageOffset.flatMap(CGFloat.init),
                                           title: title,
                                           mode: readingMode))
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
    var chapter: ThreadSafeChapter

    var body: some View {
        SmartNavigationView {
            STTWebView(url: URL(string: chapter.webUrl ?? ""))
                .closeButton()
                .navigationTitle(chapter.displayName)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
