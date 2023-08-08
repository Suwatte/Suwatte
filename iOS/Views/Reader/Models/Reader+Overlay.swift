//
//  Reader+Overlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation


struct SliderControl {
    var min: CGFloat = 0.0
    var current: CGFloat = 0.0
    var max: CGFloat = 1000.0

    var isScrubbing = false

    mutating func setCurrent(_ val: CGFloat) {
        current = val
    }

    mutating func setRange(_ min: CGFloat, _ max: CGFloat) {
        self.min = min
        self.max = max
    }
}

struct MenuControl : Hashable {
    var menu = false
    var chapterList = false
    var comments = false
    var settings = false
    var transitionOption = false

    mutating func toggleMenu() {
        menu.toggle()
    }

    mutating func hideMenu() {
        menu = false
    }

    mutating func toggleChapterList() {
        chapterList.toggle()
    }

    mutating func toggleSettings() {
        settings.toggle()
    }

    mutating func toggleComments() {
        comments.toggle()
    }
}
