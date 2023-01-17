//
//  ReaderPage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-14.
//

import Foundation





class ReaderPage {

    var page: ReaderView.Page
    
    /**
     Indicates whether this view should stand alone when in double paged
     */
    var isolatedPage: Bool = false
    /**
     Indicates Whether This Page is the First Half of a Split Page
     */
    var firstHalf: Bool?
    
    /**
     Indicates Whether This Page is a Wide Page i.e Page Width > Page Height
     */
    var widePage: Bool = false
    
    var isFullPage: Bool {
        isolatedPage || widePage
    }
    
    var didIsolate: Bool = false
    init(page: ReaderView.Page) {
        self.page = page
    }
    
}
