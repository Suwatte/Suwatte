//
//  Panel+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation

struct PanelPage: Hashable, Sendable {
    init(page: ReaderPage) {
        self.page = page
    }
    
    let page: ReaderPage
    
    /**
     Indicates Whether This Page is the Second Half of a Split Page
     */
    var isSplitPageChild = false
    

    var secondaryPage: ReaderPage?
    
    func isHolding(_ page: ReaderPage) -> Bool {
        page == page || secondaryPage == page
    }
}

