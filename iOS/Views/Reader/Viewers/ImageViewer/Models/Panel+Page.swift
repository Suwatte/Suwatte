//
//  Panel+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation

struct PanelPage: Hashable, Sendable {
    
    let page: ReaderPage
    
    /**
     Indicates Whether This Page is the Second Half of a Split Page
     */
    var isSecondaryPage = false
    
    init(page: ReaderPage) {
        self.page = page
    }
    
}

