//
//  Reader+State.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-25.
//

import Foundation

struct InitialIVState {
    let chapters: [ThreadSafeChapter]
    let openTo: ThreadSafeChapter
    let pageIndex: Int?
    let pageOffset: CGFloat?
    let title: String
    let mode: ReadingMode
}

struct CurrentViewerState: Hashable {
    var chapter: ThreadSafeChapter
    var page: Int
    var pageCount: Int
    var hasPreviousChapter: Bool
    var hasNextChapter: Bool

    static var placeholder: Self {
        .init(chapter: .init(id: "",
                             sourceId: "",
                             chapterId: "",
                             contentId: "",
                             index: 0,
                             number: 0,
                             volume: 0,
                             title: nil,
                             language: "",
                             date: .now,
                             webUrl: nil,
                             thumbnail: nil),
              page: 0,
              pageCount: 0,
              hasPreviousChapter: false,
              hasNextChapter: false)
    }
}

struct PendingViewerState: Hashable {
    var chapter: ThreadSafeChapter
    var pageIndex: Int?
    var pageOffset: CGFloat?
}
