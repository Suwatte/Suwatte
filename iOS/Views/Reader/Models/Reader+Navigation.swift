//
//  Reader+Navigation.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import SwiftUI

enum ReaderNavigation {
    enum NavigationType {
        case MENU, LEFT, RIGHT

        var color: Color {
            switch self {
            case .MENU: return .accentColor
            case .LEFT: return .init(hex: "cdb4db")
            case .RIGHT: return .init(hex: "a2d2ff")
            }
        }
    }

    struct NavigationRegion: Identifiable {
        var rect: RectP
        var type: NavigationType

        var id: String {
            UUID().uuidString
        }
    }

    struct ViewerNavigation: Identifiable {
        var regions: [NavigationRegion]
        var title: String

        func action(for point: CGPoint, ofSize size: CGSize) -> NavigationType {
            return regions.first { $0.rect.rect(for: size).contains(point) }?.type ?? NavigationType.MENU
        }

        var id: Int {
            title.hashValue
        }
    }

    struct RectP {
        var l: CGFloat
        var t: CGFloat
        var r: CGFloat
        var b: CGFloat

        func rect(for size: CGSize) -> CGRect {
            let height = size.height
            let width = size.width

            let x = width * l
            let y = height * t
            let rectW = (r - l) * width
            let rectH = (b - t) * height
            return .init(x: x, y: y, width: rectW, height: rectH)
        }
    }

    // References : https://github.com/tachiyomiorg/tachiyomi/tree/master/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/navigation

    // L Shape
    static let LNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0.0, t: 0.33, r: 0.33, b: 0.66), type: .LEFT),
        .init(rect: .init(l: 0.0, t: 0.0, r: 1.0, b: 0.33), type: .LEFT),
        .init(rect: .init(l: 0.66, t: 0.33, r: 1.0, b: 0.66), type: .RIGHT),
        .init(rect: .init(l: 0.0, t: 0.66, r: 1.0, b: 1.0), type: .RIGHT),
    ]
    static var LNavigation: ViewerNavigation = .init(regions: LNavigationRegions.reversed(), title: "L")

    // Edge
    static let EdgeNavigationRegions: [NavigationRegion] = [
        .init(rect: .init(l: 0.0, t: 0.0, r: 0.33, b: 1.0), type: .RIGHT),
        .init(rect: .init(l: 0.33, t: 0.66, r: 0.66, b: 1.0), type: .LEFT),
        .init(rect: .init(l: 0.66, t: 0.0, r: 1.0, b: 1.0), type: .RIGHT),
    ]

    static var EdgeNavigation: ViewerNavigation = .init(regions: EdgeNavigationRegions.reversed(), title: "Edge")

    // Kindlish
    static let KindlishNavigationRegion: [NavigationRegion] = [
        .init(rect: .init(l: 0.33, t: 0.33, r: 1.0, b: 1.0), type: .RIGHT),
        .init(rect: .init(l: 0.0, t: 0.33, r: 033, b: 1.0), type: .LEFT),
    ]

    static let KindlishNavigation: ViewerNavigation = .init(regions: KindlishNavigationRegion.reversed(), title: "Kindlish")

    // Standard
    static let StandardNavigationRegion: [NavigationRegion] = [
        .init(rect: .init(l: 0, t: 0, r: 0.30, b: 1), type: .LEFT),
        .init(rect: .init(l: 0.69, t: 0, r: 1, b: 1), type: .RIGHT),
    ]

    static let StandardNavigation: ViewerNavigation = .init(regions: StandardNavigationRegion.reversed(), title: "Standard")

    // Simple Array

    static let NavigationModes = [StandardNavigation, LNavigation, EdgeNavigation, KindlishNavigation]

    enum Modes: Int, CaseIterable, Identifiable {
        case standard, lNav, edge, kindlish

        var id: Int {
            rawValue
        }

        var mode: ViewerNavigation {
            switch self {
            case .standard:
                return ReaderNavigation.StandardNavigation
            case .lNav:
                return ReaderNavigation.LNavigation
            case .edge:
                return ReaderNavigation.EdgeNavigation
            case .kindlish:
                return ReaderNavigation.KindlishNavigation
            }
        }

        var description: String {
            mode.title
        }
    }
}
