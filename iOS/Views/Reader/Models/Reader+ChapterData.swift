//
//  Reader+ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation

struct ReaderChapterData: Hashable, Sendable {
    var chapter: ThreadSafeChapter
    let pages: [DSKCommon.ChapterPage]
    let text: String?
    var imageURLs: [String] {
        pages.compactMap { $0.url }
    }

    var rawDatas: [String] {
        pages.compactMap { $0.raw?.toBase64() }
    }

    let urls: [URL]
    let archivePaths: [String]
    let archiveFile: URL?
    let opdsInfo: OPDSInfo?
}

struct OPDSInfo: Hashable {
    let clientId: String
    let username: String
    let password: String
}

// MARK: Page Provider

extension ReaderChapterData {
    func getPages() throws -> [ReaderPage] {
        // Archive
        if !archivePaths.isEmpty {
            let array = zip(archivePaths.indices, archivePaths)
            return array.map { idx, data in
                .init(index: idx, count: array.underestimatedCount, chapter: chapter, archivePath: data, archiveFile: archiveFile)
            }
        }

        // Downloaded
        if !urls.isEmpty {
            let array = zip(urls.indices, urls)
            return array.map { idx, data in
                .init(index: idx, count: array.underestimatedCount, chapter: chapter, downloadURL: data)
            }
        }

        // Raw
        let raws = rawDatas
        if !raws.isEmpty {
            let array = zip(raws.indices, raws)
            return array.map { idx, data in
                .init(index: idx, count: array.underestimatedCount, chapter: chapter, rawData: data)
            }
        }

        // URL
        let images = imageURLs
        if !imageURLs.isEmpty {
            let array = zip(images.indices, images)
            return array.map { idx, data in
                .init(index: idx, count: array.underestimatedCount, chapter: chapter, hostedURL: data, opds: opdsInfo)
            }
        }

        throw DSK.Errors.NamedError(name: "PageLoader", message: "Suwatte was not able to find any readable page.")
    }
}
