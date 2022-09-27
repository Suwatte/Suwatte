//
//  DSK+Sync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-27.
//

import Foundation


extension DSKCommon {
    
    struct UpSyncedContent: Parsable, DaisukeInterface {
        var id: String
        var flag: LibraryFlag
    }
    
    
    struct DownSyncedContent: Parsable, DaisukeInterface {
        var id: String
        var title: String
        var cover: String
        var readingFlag: LibraryFlag?
    }
}
