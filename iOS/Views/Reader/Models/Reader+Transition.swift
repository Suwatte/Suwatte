//
//  Reader+Transition.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation

struct ReaderTransition: Hashable, Sendable {
    let from: ThreadSafeChapter
    let pageCount: Int?
    let to: ThreadSafeChapter?
    let type: TransitionType

    enum TransitionType: Hashable {
        case NEXT, PREV
    }

    init(from: ThreadSafeChapter, to: ThreadSafeChapter?, type: TransitionType, pageCount: Int? = nil) {
        self.from = from
        self.to = to
        self.type = type
        self.pageCount = pageCount
    }

    static func == (lhs: ReaderTransition, rhs: ReaderTransition) -> Bool {
        if lhs.from == rhs.from, lhs.to == rhs.to { return true }
        if lhs.to == rhs.from, lhs.from == rhs.to { return true }
        return false
    }
}
