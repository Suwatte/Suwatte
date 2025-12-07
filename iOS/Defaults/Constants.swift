//
//  Constants.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Foundation
import UIKit

enum STTHost {
    static let root = URL(string: "https://www.suwatte.app")!

    static let notFound = root.appendingPathComponent("404")
}

let DEFAULT_LIBRARY_SECTIONS = ["library.local", "library.lists", "library.downloads", "library.collections", "library.flags"]

@MainActor
func STTUserDefaults() -> [String: Any] {
    [
        STTKeys.PagedDirection: true,
        STTKeys.ForceTransition: true,
        STTKeys.TapSidesToNavigate: true,
        STTKeys.ImageInteractions: true,
        STTKeys.ShowOnlyDownloadedTitles: false,
        STTKeys.LastFetchedUpdates: Date.distantPast,
        STTKeys.TileStyle: TileStyle.SEPARATED.rawValue,
        STTKeys.VerticalNavigator: ReaderNavigation.Modes.lNav.rawValue,
        STTKeys.PagedNavigator: ReaderNavigation.Modes.standard.rawValue,
        STTKeys.GridItemsPerRow_P: Int((2 * UIScreen.main.bounds.width) / 375), // IPhone 13 Mini
        STTKeys.GridItemsPerRow_LS: Int((6 * UIScreen.main.bounds.height) / 812),
        STTKeys.TimeoutDuration: LocalAuthManager.TimeoutDuration.immediately.rawValue,
        STTKeys.LibrarySections: DEFAULT_LIBRARY_SECTIONS,
        STTKeys.UpdateInterval: STTUpdateInterval.oneHour.rawValue, // 1 Hour,
        STTKeys.HideNSFWRunners: true,
        STTKeys.DownsampleImages: true,
        STTKeys.LocalStorageUsesICloud: FileManager.default.ubiquityIdentityToken != nil,
        STTKeys.OverrideSourceRecommendedReadingMode: false,
    ]
}

@MainActor
func getKeyWindow() -> UIWindow? {
    UIApplication
        .shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
}

let SCHEMA_VERSION = 19
let STT_BRIDGE_VERSION = "3.0.7"

let STT_USER_AGENT = "Suwatte iOS Client V\(Bundle.main.releaseVersionNumberPretty)"
