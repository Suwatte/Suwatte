//
//  STT+CGFloat.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-30.
//

import SwiftUI

extension CGFloat {
    func map(from: ClosedRange<CGFloat>, to: ClosedRange<CGFloat>) -> CGFloat {
        let value = clamped(to: from)

        let fromRange = from.upperBound - from.lowerBound
        let toRange = to.upperBound - to.lowerBound
        let result = (((value - from.lowerBound) / fromRange) * toRange) + to.lowerBound
        return result
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
