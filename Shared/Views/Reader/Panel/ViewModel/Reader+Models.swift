//
//  Reader+Protocols.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import Kingfisher
import SwiftUI

// MARK: Protocols

protocol ReaderTransitionManager {
    func didMove(toPage page: ReaderView.Page)
    func onChapterCompleted(chapter: ReaderView.ReaderChapter)
}

protocol ReaderSliderManager {
    var slider: ReaderView.SliderControl { get set }

    func updateSliderOffsets(min: CGFloat, max: CGFloat)
}

protocol ReaderMenuManager {
    var menu: ReaderView.MenuControl { get set }

    func toggleMenu()
    func toggleComments()
    func toggleChaperList()
    func toggleSettings()
    func toggleTransitionOptions()
}

protocol SliderPublisher {
    func getScrubbableRange()
}

protocol ReaderChapterLoader {
    func loadChapterData(for chapter: ReaderView.ReaderChapter, setMarker: Bool)
}

// MARK: Structs

extension ReaderView {
    // MARK: Slider Control

    struct SliderControl {
        var min: CGFloat = 0.0
        var current: CGFloat = 0.0
        var max: CGFloat = 1000.0

        var isScrubbing = false

        mutating func setCurrent(_ val: CGFloat) {
            current = val
        }

        mutating func setRange(_ min: CGFloat, _ max: CGFloat) {
            self.min = min
            self.max = max
        }
    }

    struct MenuControl {
        var menu = false
        var chapterList = false
        var comments = false
        var settings = false
        var transitionOption = false

        mutating func toggleMenu() {
            menu.toggle()
        }

        mutating func hideMenu() {
            menu = false
        }

        mutating func toggleChapterList() {
            chapterList.toggle()
        }

        mutating func toggleSettings() {
            settings.toggle()
        }

        mutating func toggleComments() {
            comments.toggle()
        }
    }

    // MARK: Reader Chapter
    struct ChapterData: Hashable {
        var id: String
        var contentId: String
        var sourceId: String
        var chapterId: String
        
        var pages: [DSKCommon.ChapterPage]
        var text: String?

        var imageURLs: [String] {
            pages.compactMap { $0.url }
        }
        var rawDatas: [String] {
            pages.compactMap { $0.raw?.toBase64() }
        }
        var urls: [URL] = []
        var archivePaths: [String] = []
    }

    class ReaderChapter: Equatable, ObservableObject {
        var chapter: ThreadSafeChapter
        @Published var data = Loadable<ChapterData>.idle {
            didSet {
                guard let chapterData = data.value else {
                    pages = nil
                    return
                }

                let chapterId = chapter._id

                // Archive
                if !chapterData.archivePaths.isEmpty {
                    let paths = chapterData.archivePaths
                    let arr = zip(paths.indices, paths)
                    let file = chapter.contentId
                    pages = arr.map {
                        .init(page: Page(index: $0, chapterId: chapterId, contentId: chapter.contentId, sourceId: chapter.sourceId, archivePath: $1, archiveFile: file))
                    }
                }
                // Downloaded
                else if !chapterData.urls.isEmpty {
                    let urls = chapterData.urls
                    let arr = zip(urls.indices, urls)
                    pages = arr.map {
                        .init(page: Page(index: $0, chapterId: chapterId, contentId: chapter.contentId, sourceId: chapter.sourceId, downloadURL: $1))
                    }
                }

                // Raws
                else if !chapterData.rawDatas.isEmpty {
                    let raws = chapterData.rawDatas
                    let arr = zip(raws.indices, raws)
                    pages = arr.map {
                        .init(page: Page(index: $0, chapterId: chapterId, contentId: chapter.contentId, sourceId: chapter.sourceId, rawData: $1))
                    }
                }
                // URL
                else {
                    let images = chapterData.imageURLs
                    let arr = zip(images.indices, images)

                    pages = arr.map {
                        .init(page: Page(index: $0, chapterId: chapterId, contentId: chapter.contentId, sourceId: chapter.sourceId, hostedURL: $1))
                    }
                }
            }
        }

        var requestedPageIndex = 0 // Current Page
        var requestedPageOffset: CGFloat? // offset for current page
        init(chapter: ThreadSafeChapter) {
            self.chapter = chapter
        }

        static func == (lhs: ReaderChapter, rhs: ReaderChapter) -> Bool {
            return lhs.chapter.chapterId == rhs.chapter.chapterId
        }

        @Published var pages: [ReaderPage]?

        enum ChapterType {
            case EXTERNAL, LOCAL, OPDS
        }
    }

    
    struct Page: Hashable {
        
        
        var index: Int
        var isLocal: Bool {
            archivePath != nil || downloadURL != nil
        }

        var number: Int {
            index + 1
        }

        var chapterId: String
        var contentId: String
        var sourceId: String

        var downloadURL: URL? = nil
        var hostedURL: String? = nil
        var rawData: String? = nil
        var archivePath: String? = nil
        var archiveFile: String? = nil

        static func == (lhs: Page, rhs: Page) -> Bool {
            return lhs.chapterId == rhs.chapterId && lhs.index == rhs.index
        }

        var CELL_KEY: String {
            "\(chapterId)||\(index)"
        }
    }

    // MARK: ReaderTransition

    class Transition: Equatable {
        var from: ThreadSafeChapter
        var to: ThreadSafeChapter?
        var type: TransitionType

        enum TransitionType {
            case NEXT, PREV
        }

        init(from: ThreadSafeChapter, to: ThreadSafeChapter?, type: TransitionType) {
            self.from = from
            self.to = to
            self.type = type
        }

        static func == (lhs: Transition, rhs: Transition) -> Bool {
            if lhs.from == rhs.from, lhs.to == rhs.to { return true }
            if lhs.to == rhs.from, lhs.from == rhs.to { return true }
            return false
        }
    }
}

extension StoredChapter {
    static func == (lhs: StoredChapter, rhs: StoredChapter) -> Bool {
        lhs._id == rhs._id
    }
}

extension ReaderView.Page {
    func toKFSource() -> Kingfisher.Source? {
        // Hosted Image
        if let hostedURL = hostedURL, let url = URL(string: hostedURL) {
            return url.convertToSource(overrideCacheKey: CELL_KEY)
        }

        // Downloaded
        else if let url = downloadURL {
            return url.convertToSource(overrideCacheKey: CELL_KEY)
        }

        // Archive
        else if let archivePath = archivePath, let file = archiveFile {
            let provider = LocalContentImageProvider(cacheKey: CELL_KEY, fileId: file, pagePath: archivePath)
            return .provider(provider)
        }

        // Raw Data
        else if let rawData = rawData {
            let provider = Base64ImageDataProvider(base64String: rawData, cacheKey: CELL_KEY)
            return .provider(provider)
        }

        return nil
    }
}


extension StoredChapterData {
    func toReadableChapterData() -> ReaderView.ChapterData {
        .init(id: _id, contentId: chapter?.contentId ?? "",
              sourceId: chapter?.sourceId ?? "",
              chapterId: chapter?.chapterId ?? "",
              pages: pages.map({ .init(url: $0.url, raw: $0.raw)}),
              text: text,
              urls: urls,
              archivePaths: archivePaths
        )
    }
}
