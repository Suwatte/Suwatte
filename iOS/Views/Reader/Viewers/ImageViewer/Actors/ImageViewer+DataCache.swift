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

    func setChapters(_ data: [ThreadSafeChapter]) {
        chapters = OrderedSet(data)
    }

    func load(for chapter: ThreadSafeChapter) async throws {
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
        let next = chapters.getOrNil(index + 1)
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
            let archivedContent = await actor.getArchivedcontentInfo(id)

            guard let archivedContent else {
                throw DSK.Errors.NamedError(name: "DataLoader", message: "Failed to locate archive information")
            }

            let url = archivedContent.getURL()
            guard let url else {
                throw DSK.Errors.NamedError(name: "FileManager", message: "File not found.")
            }
            let arr = try ArchiveHelper().getImagePaths(for: url)
            let obj = StoredChapterData()
            obj.chapter = chapter.toStored()
            obj.archivePaths = arr
            obj.archiveURL = url
            return obj.toReadableChapterData(with: chapter)

        case .EXTERNAL:
            // Get from SDM
            if let data = try await SDM.shared.getChapterData(for: chapter.id) {
                return data.toReadableChapterData(with: chapter)
            }

            // Get from Database
            if let data = await actor.getChapterData(forId: chapter.id) {
                return data.toReadableChapterData(with: chapter)
            }
            // Get from source
            guard let source = await DSK.shared.getSource(id: chapter.sourceId) else {
                throw DaisukeEngine.Errors.NamedError(name: "Engine", message: "Source Not Found")
            }

            let data = try await source.getChapterData(contentId: chapter.contentId, chapterId: chapter.chapterId)
            if source.ablityNotDisabled(\.disableChapterDataCaching) {
                await actor.saveChapterData(data: data, chapter: chapter)
            }
            return data.toStored(withStoredChapter: chapter.toStored()).toReadableChapterData(with: chapter)

        case .OPDS:
            let obj = StoredChapterData()
            obj.chapter = chapter.toStored()
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
            obj.pages.append(objectsIn: pages)
            obj.opdsInfo = info
            return obj.toReadableChapterData(with: chapter)
        }
    }
}

extension IVDataCache {
    func getChapter(after chapter: ThreadSafeChapter) -> ThreadSafeChapter? {
        let index = chapters.firstIndex(of: chapter)
        guard let index else {
            return nil
        }

        let next = chapters.getOrNil(index + 1)

        guard let next else {
            return nil
        }

        guard next.number != chapter.number else {
            return getChapter(after: next)
        }

        return next
    }

    func getChapter(before chapter: ThreadSafeChapter) -> ThreadSafeChapter? {
        let index = chapters.firstIndex(of: chapter)
        guard let index, index > 0 else {
            return nil
        }

        let prev = chapters.getOrNil(index - 1)

        guard let prev else {
            return nil
        }

        guard prev.number != chapter.number else {
            return getChapter(before: prev)
        }

        return prev
    }
}
