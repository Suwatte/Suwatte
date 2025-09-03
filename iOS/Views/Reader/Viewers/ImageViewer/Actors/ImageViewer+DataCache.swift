//
//  ImageViewer+DataCache.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import OrderedCollections

enum PanelViewerItem: Hashable {
    case transition(ReaderTransition)
    case page(PanelPage)

    var chapter: ThreadSafeChapter {
        switch self {
        case let .transition(readerTransition):
            return readerTransition.from
        case let .page(panelPage):
            return panelPage.page.chapter
        }
    }

    var isPage: Bool {
        switch self {
        case .page:
            return true
        case .transition:
            return false
        }
    }
}

final actor IVDataCache {
    var cache: [String: [ReaderPage]] = [:]
    var chapters: OrderedSet<ThreadSafeChapter> = []
    var nextCache: [String: ThreadSafeChapter] = [:] // stores the next chapter for the provided ID. Avoids doing multiple filtering calls
    var prevCache: [String: ThreadSafeChapter] = [:] // stores the prev chapter for the provided ID. Avoids doing multiple filtering calls

    func setChapters(_ data: [ThreadSafeChapter]) {
        chapters = OrderedSet(data)
    }

    func load(for chapter: ThreadSafeChapter) async throws {
        guard get(chapter.id) == nil else { return }
        let data = try await getData(chapter)
        let pages = try data.getPages()
        cache.updateValue(pages, forKey: chapter.id)
    }

    func get(_ key: String) -> [ReaderPage]? {
        cache[key]
    }

    func getCount(_ key: String) -> Int {
        cache[key]?.count ?? 0
    }

    func prepare(_ key: String) -> [PanelViewerItem]? {
        let pages = cache[key]

        guard let pages, let chapter = pages.first?.chapter, let index = chapters.firstIndex(of: chapter) else {
            Logger.shared.warn("target chapter was not found")
            return nil
        }

        var objects: [PanelViewerItem] = []

        // First Chapter, Append No Previous Chapter Transition Block
        if index == 0 {
            let transition = ReaderTransition(from: chapter, to: nil, type: .PREV)
            objects.append(.transition(transition))
        }

        // Append all pages
        let readerPages = pages.map { PanelViewerItem.page(PanelPage(page: $0)) }
        objects.append(contentsOf: readerPages)

        // Add Transition to next
        let next = getChapter(after: chapter)

        if Preferences.standard.currentReadingMode == .VERTICAL {
            let transition = ReaderTransition(from: chapter,
                                              to: next,
                                              type: .NEXT,
                                              pageCount: readerPages.count)
            objects.append(.transition(transition))
        } else {
            let showTransitions = Preferences.standard.forceTransitions

            guard showTransitions || next == nil else {
                return objects
            }

            guard next == nil || pages.count >= 10 else {
                return objects
            }

            let transition = ReaderTransition(from: chapter,
                                              to: next,
                                              type: .NEXT,
                                              pageCount: readerPages.count)
            objects.append(.transition(transition))
        }

        // Return generated pages
        return objects
    }
}

extension IVDataCache {
    func getData(_ chapter: ThreadSafeChapter) async throws -> ReaderChapterData {
        try Task.checkCancellation()
        let actor = await RealmActor.shared()
        switch chapter.chapterType {
        case .LOCAL:
            let id = chapter.contentId
            let archivedContent = await actor.getArchivedContentInfo(id)

            guard let archivedContent else {
                throw DSK.Errors.NamedError(name: "DataLoader", message: "Failed to locate archive information")
            }

            let url = archivedContent.getURL()
            guard let url else {
                throw DSK.Errors.NamedError(name: "FileManager", message: "File not found.")
            }
            let arr = try ArchiveHelper().getImagePaths(for: url)
            let obj = StoredChapterData(archivePaths: arr, archiveURL: url)
            return obj.toReadableChapterData(with: chapter)

        case .EXTERNAL:
            // Get from SDM
            if let data = try await SDM.shared.getChapterData(for: chapter.id) {
                return data.toReadableChapterData(with: chapter)
            }

            // Get from source
            guard let source = await DSK.shared.getSource(id: chapter.sourceId) else {
                throw DaisukeEngine.Errors.NamedError(name: "Engine", message: "Source Not Found")
            }

            let data = try await source.getChapterData(contentId: chapter.contentId, chapterId: chapter.chapterId, chapter: chapter)

            return data.toStored(withStoredChapter: chapter.toStored()).toReadableChapterData(with: chapter)

        case .OPDS:
            let baseLink = chapter.chapterId
            let publication = await actor.getPublication(id: chapter.id)
            guard let publication, let client = publication.client else {
                throw DSK.Errors.NamedError(name: "OPDS", message: "Unable to fetch OPDS Content")
            }
            let pageCount = publication.pageCount
            let pages = Array(0 ..< pageCount).map { num -> StoredChapterPage in
                let page = StoredChapterPage()
                page.url = baseLink.replacingOccurrences(of: "STT_PAGE_NUMBER_PLACEHOLDER", with: num.description)
                return page
            }

            let info = OPDSInfo(clientId: client.id, userName: client.userName)
            var obj = StoredChapterData()
            obj.pages.append(contentsOf: pages)
            obj.opdsInfo = info
            return obj.toReadableChapterData(with: chapter)
        }
    }
}

extension IVDataCache {
    func getChapter(after chapter: ThreadSafeChapter) -> ThreadSafeChapter? {
        if let next = nextCache[chapter.id] {
            return next
        }

        let index = chapters.firstIndex(of: chapter)
        guard let index else {
            return nil
        }

        let next = ChapterManager.getChapter(after: true, index: index, chapters: chapters)

        nextCache[chapter.id] = next
        return next
    }

    func getChapter(before chapter: ThreadSafeChapter) -> ThreadSafeChapter? {
        if let prev = prevCache[chapter.id] {
            return prev
        }

        let index = chapters.firstIndex(of: chapter)
        guard let index else {
            return nil
        }

        let prev = ChapterManager.getChapter(after: false, index: index, chapters: chapters)

        prevCache[chapter.id] = prev
        return prev
    }
}
