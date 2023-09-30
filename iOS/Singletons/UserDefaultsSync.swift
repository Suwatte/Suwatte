//
//  UserDefaultsSync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-04.
//

import Foundation
import Zephyr

class UDSync {
    static func sync() {
        guard isUserLoggedInToiCloud() else { return }
        var keys: [String] = [STTKeys.OpenAllTitlesOnAppear,
                              STTKeys.TileStyle,
                              STTKeys.LibraryGridSortKey,
                              STTKeys.LibraryGridSortOrder,
                              STTKeys.ChapterListSortKey,
                              STTKeys.ChapterListDescending,
                              STTKeys.ChapterListFilterDuplicates,
                              STTKeys.ChapterListShowOnlyDownloaded,
                              STTKeys.ForceTransition,
                              STTKeys.BackgroundColor,
                              STTKeys.UseSystemBG,
                              STTKeys.PagedNavigator,
                              STTKeys.VerticalNavigator,
                              STTKeys.LastFetchedUpdates,
                              STTKeys.LibraryAuth,
                              STTKeys.ShowOnlyDownloadedTitles,
                              STTKeys.LibraryShowBadges,
                              STTKeys.LibraryBadgeType,
                              STTKeys.LocalSortLibrary,
                              STTKeys.LocalOrderLibrary,
                              STTKeys.LocalThumnailOnly,
                              STTKeys.LocalHideInfo,
                              STTKeys.DownloadsSortLibrary,
                              STTKeys.LibrarySections,
                              STTKeys.SelectiveUpdates,
                              STTKeys.AppAccentColor,
                              STTKeys.UpdateInterval,
                              STTKeys.LastAutoBackup,
                              STTKeys.CheckLinkedOnUpdateCheck,
                              STTKeys.DefaultUserAgent,
                              STTKeys.UpdateContentData,
                              STTKeys.UpdateSkipConditions,
                              STTKeys.FilteredProviders,
                              STTKeys.FilteredLanguages,
                              STTKeys.AlwaysAskForLibraryConfig,
                              STTKeys.DefaultCollection,
                              STTKeys.DefaultReadingFlag,
                              STTKeys.DefaultPanelReadingMode,
                              STTKeys.MoveDownloadToArchive,
                              STTKeys.OnlyCheckForUpdateInSpecificCollections,
                              STTKeys.UpdateApprovedCollections,
                              STTKeys.SourcesDisabledFromHistory,
                              STTKeys.SourcesDisabledFromGlobalSearch,
                              STTKeys.GlobalContentLanguages,
                              STTKeys.GlobalHideNSFW,
                              STTKeys.OverrideSourceRecommendedReadingMode]

        let DynamicKeyPrefixes = ["RUNNER.IRH",
                                  "RUNNER.PLR",
                                  "RUNNER.BLP",
                                  "RUNNER.SCPP",
                                  "RUNNER.THPO",
                                  "READER.type"
        ]
        
        func startsWith(_ v: String) -> Bool {
            DynamicKeyPrefixes.contains(where: { v.starts(with: $0) })
        }
        let DynamicKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter(startsWith(_:))
        keys.append(contentsOf: DynamicKeys)

        #if DEBUG
            Zephyr.debugEnabled = true
        #endif
        Task { @MainActor [keys] in
            Zephyr.syncUbiquitousKeyValueStoreOnChange = false // Turns off instantaneous synchronization
            Zephyr.sync(keys: keys)
            Zephyr.addKeysToBeMonitored(keys: keys)
        }

    }
    
    private static func isUserLoggedInToiCloud() -> Bool {
       FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }
}
