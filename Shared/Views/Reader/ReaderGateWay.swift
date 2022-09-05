//
//  ReaderGateWay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-15.
//

import Kingfisher
import SwiftUI

struct ReaderGateWay: View {
    @State var readingMode: ReadingMode
    var chapterList: [StoredChapter]
    var openTo: StoredChapter
    var pageIndex: Int?
    var title: String?
    var body: some View {
        Group {
            switch readingMode {
            case .NOVEL:
                NovelReaderView(model: .init(chapterList: chapterList, openTo: openTo))
            case .WEB:
                WebReader(chapter: openTo)
            default:
                ReaderView(model: .init(chapterList: chapterList, openTo: openTo, title: title, pageIndex: pageIndex, readingMode: readingMode))
            }
        }
        .onDisappear {
            KingfisherManager.shared.cache.memoryStorage.removeAll()
        }
    }
}

struct WebReader: View {
    var chapter: StoredChapter

    var body: some View {
        NavigationView {
            STTWebView(url: URL(string: chapter.webUrl))
                .closeButton()
                .navigationTitle(chapter.displayName)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
