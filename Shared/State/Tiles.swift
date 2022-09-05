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

    var tileHeight: CGFloat {
        self == .COMPACT ? 240.0 : 275.0
    }

    var tileRatio: Double {
        self == .COMPACT ? 1.4 : 1.6
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
