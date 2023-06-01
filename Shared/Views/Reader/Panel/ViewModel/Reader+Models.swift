//
//  Reader+Protocols.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-29.
//

import SwiftUI
import Nuke

// MARK: Protocols

protocol ReaderTransitionManager {
    func didMove(toPage page: ReaderView.Page)
    func onChapterCompleted(chapter: ReaderView.ReaderChapter)
}

protocol ReaderSliderManager  {
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

                let chapterId = chapter.id

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
        
        var targetWidth: CGFloat = UIScreen.mainScreen.bounds.width

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
        lhs.id == rhs.id
    }
}

extension ReaderView.Page {
    private func prepareImageURL(_ url: URL) async throws -> URLRequest {
        let sourceId = sourceId
        guard let source = try SourceManager.shared.getContentSource(id: sourceId) as? any ModifiableSource, source.config.hasThumbnailInterceptor  else {
            return .init(url: url)
        }
        let response = try await source.willRequestImage(request: .init(url: url.absoluteString))
        let request = try response.toURLRequest()
        return request
    }
    
    private func prepareProcessors() -> [ImageProcessing] {
        var processors = [ImageProcessing]()
        let cropWhiteSpaces = Preferences.standard.cropWhiteSpaces
        let downSampleImage = Preferences.standard.downsampleImages
        
        if downSampleImage || isLocal { // Always Downsample Local Images
            processors.append(NukeDownsampleProcessor(width: targetWidth))
        }
        
        if cropWhiteSpaces {
            processors.append(NukeWhitespaceProcessor())
        }
        
        return processors
    }
    
    func load() async throws -> AsyncImageTask {
        

        let request = try await getImageRequest()
        
        guard let request else {
            throw DSK.Errors.NamedError(name: "Image Loader", message: "No handler resolved the requested page.")
        }
        
        let task = ImagePipeline.shared.imageTask(with: request)
        return task
    }
    
    func getImageRequest() async throws -> ImageRequest? {
        var request: ImageRequest? = nil
        
        // Hosted Image
        if let hostedURL = hostedURL, let url = URL(string: hostedURL) {
            // Load Hosted Image
            request = try await loadImageFromNetwork(url)
        }
        
        // Downloaded
        else if let url = downloadURL {
            // Load Downloaded Image
            request = try await loadImageFromDownloadFolder(url)
        }
        
        // Archive
        else if let archivePath = archivePath, let file = archiveFile {
            request = try await loadImageFromArchive(file, archivePath, CELL_KEY)
        }
        
        // Raw Data
        else if let rawData = rawData {
            request = try await loadImageFromBase64EncodedString(rawData, CELL_KEY)
        }
        return request
    }
    
    private func loadImageFromNetwork(_ url: URL) async throws -> ImageRequest {
        let request = try await prepareImageURL(url)
        return ImageRequest(urlRequest: request, processors: prepareProcessors())
    }
    
    private func loadImageFromDownloadFolder(_ url: URL) async throws -> ImageRequest {
        let request = ImageRequest(url: url, processors: prepareProcessors(), options: .disableDiskCache)
        return request
    }
    
    private func loadImageFromBase64EncodedString(_ str: String, _ key: String ) async throws ->  ImageRequest {
        var request = ImageRequest(id: key) {
            let data = Data(base64Encoded: str)
            guard let data else {
                throw DSK.Errors.NamedError(name: "Image Loader", message: "Failed to decode image from base64 string. Please report this to the source authors.")
            }
            
            return data
        }
        request.options = .disableDiskCache
        request.processors = prepareProcessors()
        
        return request
    }
    
    private func loadImageFromArchive(_ file: String, _ path: String, _ key: String) async throws -> ImageRequest {
        let request = ImageRequest(id: key) {
            try LocalContentManager.shared.getImageData(for: file, ofName: path)
        }
        return request
    }
    
}




extension StoredChapterData {
    func toReadableChapterData() -> ReaderView.ChapterData {
        .init(id: _id, contentId: chapter?.contentId ?? "",
              sourceId: chapter?.sourceId ?? "",
              chapterId: chapter?.chapterId ?? "",
              pages: pages.map { .init(url: $0.url, raw: $0.raw) },
              text: text,
              urls: urls,
              archivePaths: archivePaths)
    }
}
 
