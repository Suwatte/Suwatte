//
//  Tiles.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import Foundation
import SwiftUI // The CGFloat type DNE on foundation

enum TileStyle: Int, CaseIterable {
    case COMPACT, SEPARATED

    var titleHeight: CGFloat {
        self == .SEPARATED ? 50 : 0
    }
    var description: String {
        switch self {
        case .COMPACT:
            return "Compact"
        case .SEPARATED:
            return "Separated"
        }
    }
}
