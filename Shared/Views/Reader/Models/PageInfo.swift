//
//  PageInfo.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-14.
//

import Foundation


struct PageInfo: Hashable {
    
    
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

    static func == (lhs: PageInfo, rhs: PageInfo) -> Bool {
        return lhs.chapterId == rhs.chapterId && lhs.index == rhs.index
    }

    var CELL_KEY: String {
        "\(chapterId)||\(index)"
    }
}
