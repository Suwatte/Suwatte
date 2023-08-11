//
//  Reader+Overlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation


struct SliderControl: Hashable {
    var current: Double = 0.0
    var isScrubbing = false
}

struct MenuControl : Hashable {
    var menu = false
    var chapterList = false
    var comments = false
    var settings = false
    var transitionOption = false
}
