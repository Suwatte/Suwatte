//
//  ChapterData.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation

struct StoredChapterData {
    var pages: [StoredChapterPage] = []
    var text: String?

    var imageURLs: [String] {
        pages.compactMap { $0.url }
    }

    var rawDatas: [String] {
        pages.compactMap { $0.raw?.toBase64() }
    }

    var urls: [URL] = []
    var archivePaths: [String] = []
    var archiveURL: URL?
    var opdsInfo: OPDSInfo?
}

class StoredChapterPage: Parsable {
    var url: String?
    var raw: String?
}
