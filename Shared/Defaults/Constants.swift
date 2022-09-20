//
//  Constants.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Foundation
import UIKit

let DEFAULT_THUMB = "https://kpopping.com/documents/e6/5/1440/BLACKPINK-Rose-for-Saint-Laurent-Spring-2022-collection-documents-3.jpeg"

typealias JSON = [String: Any]

enum STTHost {
    static var root = URL(string: "https://suwatte.mantton.com")!

    static var notFound = root.appendingPathComponent("404")
    static var api = root.appendingPathComponent("api")
    static var tnc = root.appendingPathComponent("tnc")

    static var coverNotFound = notFound.appendingPathComponent("thumb.png")
}

let STTUserDefaults: [String: Any] = [
    STTKeys.PagedDirection: true,
    STTKeys.ForceTransition: true,
    STTKeys.TapSidesToNavigate: true,
    STTKeys.ImageInteractions: true,
    STTKeys.ShowUpdateBadges: true,
    STTKeys.ShowOnlyDownloadedTitles: false,
    STTKeys.LastFetchedUpdates: Date.distantPast,
    STTKeys.TileStyle: TileStyle.SEPARATED.rawValue,
    STTKeys.VerticalNavigator: ReaderView.ReaderNavigation.Modes.lNav.rawValue,
    STTKeys.PagedNavigator: ReaderView.ReaderNavigation.Modes.standard.rawValue,
    STTKeys.GridItemsPerRow_P: Int((2 * UIScreen.main.bounds.width) / 375), // IPhone 13 Mini
    STTKeys.GridItemsPerRow_LS: Int((6 * UIScreen.main.bounds.height) / 812),
    STTKeys.TimeoutDuration: LocalAuthManager.TimeoutDuration.immediately.rawValue,
    STTKeys.LibrarySections: LibraryView.LibrarySectionOrder.allCases.map { $0.rawValue },
]

let SCHEMA_VERSION = 9
let STT_BRIDGE_VERSION = "1.1.0"

let KEY_WINDOW = UIApplication
    .shared
    .connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }

let STT_USER_AGENT = "Suwatte iOS Client V\(Bundle.main.releaseVersionNumberPretty)"
