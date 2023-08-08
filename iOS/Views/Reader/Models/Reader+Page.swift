//
//  Reader+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation


struct ReaderPage: Hashable, Sendable {
    let index: Int
    let chapterPageCount: Int
    var isLocal: Bool {
        archivePath != nil || downloadURL != nil
    }
    
    var number: Int {
        index + 1
    }
    
    let chapter: ThreadSafeChapter
    
    let downloadURL: URL?
    let hostedURL: String?
    let rawData: String?
    let archivePath: String?
    let archiveFile: URL?
    
    let opds: OPDSInfo?
    
    init(index: Int, count: Int, chapter: ThreadSafeChapter, downloadURL: URL? = nil, hostedURL: String?  = nil, rawData: String? = nil, archivePath: String? = nil, archiveFile: URL? = nil, opds: OPDSInfo? = nil) {
        self.index = index
        self.chapter = chapter
        self.downloadURL = downloadURL
        self.hostedURL = hostedURL
        self.rawData = rawData
        self.archivePath = archivePath
        self.archiveFile = archiveFile
        self.opds = opds
        self.chapterPageCount = count
    }
    
    var CELL_KEY: String {
        "\(chapter.id)||\(index)"
    }
}
