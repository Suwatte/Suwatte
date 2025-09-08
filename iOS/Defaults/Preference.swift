//
//  Preference.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-31.
//  Refernce: https://www.avanderlee.com/swift/appstorage-explained/

import Combine
import Foundation
import SwiftUI

final class Preferences {
    static let standard = Preferences(userDefaults: .standard)
    fileprivate let userDefaults: UserDefaults

    /// Sends through the changed key path whenever a change occurs.
    var preferencesChangedSubject = PassthroughSubject<AnyKeyPath, Never>()

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    @UserDefault(STTKeys.incognito)
    var incognitoMode: Bool = false
    // Page Level
    @UserDefault(STTKeys.CropWhiteSpaces)
    var cropWhiteSpaces: Bool = false

    @UserDefault(STTKeys.DownsampleImages)
    var downsampleImages: Bool = false

    @UserDefault(STTKeys.ImageInteractions)
    var imageInteractions: Bool = false

    @UserDefault(STTKeys.VerticalPagePadding)
    var VerticalPagePadding: Bool = false

    // Reader Level
    @UserDefault(STTKeys.IsReadingVertically)
    var isReadingVertically: Bool = false

    @UserDefault(STTKeys.VerticalPagerEnabled)
    var isPagingVertically: Bool = false

    @UserDefault(STTKeys.IsDoublePagedEnabled)
    var isDoublePagedEnabled: Bool = false

    @UserDefault(STTKeys.PagedDirection)
    var readingLeftToRight: Bool = true

    @UserDefault(STTKeys.ForceTransition)
    var forceTransitions: Bool = true

    @UserDefault(STTKeys.LibraryAuth)
    var protectContent: Bool = false

    @UserDefault(STTKeys.TimeoutDuration)
    var timeoutDuration: LocalAuthManager.TimeoutDuration = .afer5

    @UserDefault(STTKeys.TapSidesToNavigate)
    var tapSidesToNavigate: Bool = true

    @UserDefault(STTKeys.ShowNavigationOverlay)
    var displayNavOverlay: Bool = true

    @UserDefault(STTKeys.InvertNavigationSides)
    var invertTapSidesToNavigate = false

    @UserDefault(STTKeys.NovelFontSize)
    var novelFontSize = 25

    @UserDefault(STTKeys.NovelFontColor)
    var novelFontColor: Color = .primary

    @UserDefault(STTKeys.NovelUseSystemColor)
    var novelUseSystemColor = true

    @UserDefault(STTKeys.NovelBGColor)
    var novelBGColor: Color = .primary

    @UserDefault(STTKeys.NovelOrientationLock)
    var novelOrientationLock = true

    @UserDefault(STTKeys.NovelUseVertical)
    var novelUseVertical = false

    @UserDefault(STTKeys.NovelUseDoublePaged)
    var novelUseDoublePaged = false

    @UserDefault(STTKeys.NovelFont)
    var novelFont = "AvenirNextCondensed-Regular"

    @UserDefault(STTKeys.SelectiveUpdates)
    var selectiveUpdates = false

    @UserDefault(STTKeys.VerticalAutoScroll)
    var verticalAutoScroll = false

    @UserDefault(STTKeys.VerticalAutoScrollSpeed)
    var verticalAutoScrollSpeed: Double = 16

    @UserDefault(STTKeys.DefaultUserAgent)
    var userAgent = "Chrome Safari"

    @UserDefault(STTKeys.ImageScaleType)
    var imageScaleType = ImageScaleOption.screen

    @UserDefault(STTKeys.AppAccentColor)
    var accentColor = Color.sttDefault

    @UserDefault(STTKeys.ReaderType)
    var readerType = ReadingMode.PAGED_COMIC

    @UserDefault(STTKeys.UpdateSkipConditions)
    var skipConditions: [SkipCondition] = []

    @UserDefault(STTKeys.VerticalPillarBoxEnabled)
    var usePillarBox = false

    @UserDefault(STTKeys.VerticalPillarBoxPCT)
    var pillarBoxPCT = 1.0 // 0.15 -> 1.0

    @UserDefault(STTKeys.ForceTransition)
    var alwaysUseTransitions = true

    @UserDefault(STTKeys.EnableReaderHaptics)
    var enableReaderHaptics = true

    @UserDefault(STTKeys.LocalStorageUsesICloud)
    var useCloudForLocal = true

    @UserDefault(STTKeys.LocalSortLibrary)
    var directoryViewSortKey = DirectorySortOption.dateAdded

    @UserDefault(STTKeys.LocalOrderLibrary)
    var directoryViewOrderKey = true // Default to Descending

    @UserDefault(STTKeys.DefaultPanelReadingMode)
    var defaultPanelReadingMode = ReadingMode.PAGED_COMIC

    @UserDefault(STTKeys.ReaderScrollbarPosition)
    var readerScrollbarPosition = ReaderScrollbarPosition.AUTO

    @UserDefault(STTKeys.ReaderBottomScrollbarDirection)
    var readerBottomScrollbarDirection = ReaderBottomScrollbarDirection.RIGHT

    @UserDefault(STTKeys.ReaderHideMenuOnSwipe)
    var readerHideMenuOnSwipe = true

    @UserDefault(STTKeys.ReaderScrollbarWidth)
    var readerScrollbarWidth = 14.0

    @UserDefault(STTKeys.MoveDownloadToArchive)
    var archiveSourceDownload = false

    @UserDefault(STTKeys.PagedSplitsWide)
    var splitWidePages = false

    @UserDefault(STTKeys.PagedZoomWide)
    var zoomWidePages = false

    @UserDefault(STTKeys.VerticalNavigator)
    var verticalNavigator = ReaderNavigation.Modes.lNav

    @UserDefault(STTKeys.PagedNavigator)
    var horizontalNavigator = ReaderNavigation.Modes.standard

    @UserDefault(STTKeys.CurrentReadingMode)
    var currentReadingMode = ReadingMode.PAGED_COMIC

    @UserDefault(STTKeys.SourcesDisabledFromHistory)
    var disabledHistorySources = Set<String>()

    @UserDefault(STTKeys.SourcesDisabledFromGlobalSearch)
    var disabledGlobalSearchSources = Set<String>()

    @UserDefault(STTKeys.VerticalPagePaddingAmount)
    var verticalPagePaddingAmount: Int = 5

    @UserDefault(STTKeys.GlobalContentLanguages)
    var globalContentLanguages = Set<String>()

    @UserDefault(STTKeys.GlobalHideNSFW)
    var globalHideNSFW = true

    @UserDefault(STTKeys.OnlyCheckForUpdateInSpecificCollections)
    var updatesUseCollections = false

    @UserDefault(STTKeys.UpdateApprovedCollections)
    var approvedUpdateCollections = Set<String>()

    @UserDefault(STTKeys.OverrideSourceRecommendedReadingMode)
    var overrideProvidedReaderMode = false

    @UserDefault(STTKeys.BlackListOnSourceLevel)
    var blackListProviderOnSourceLevel = true

    @UserDefault(STTKeys.SyncDatabase)
    var syncDatabase = false

    @UserDefault(STTKeys.AlwaysMarkFirstPageAsSinglePanel)
    var markFirstAsSingle = true
    
    @UserDefault(STTKeys.TrackerAutoSync)
    var trackerAutoSync = true

    @UserDefault(STTKeys.UseSystemBG)
    var useSystemBG = true

    @UserDefault(STTKeys.EnableOverlay)
    var enableOverlay = false
    
    @UserDefault(STTKeys.AutoDeleteCompletedChapters)
    var autoDeleteCompletedChapters = false
}

@propertyWrapper
struct UserDefault<Value: UserDefaultsSerializable> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get { fatalError("Wrapped value should not be used.") }
        set { fatalError("Wrapped value should not be used.") }
    }

    init(wrappedValue: Value, _ key: String) {
        defaultValue = wrappedValue
        self.key = key
    }

    static subscript(
        _enclosingInstance instance: Preferences,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<Preferences, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Preferences, Self>
    ) -> Value {
        get {
            let container = instance.userDefaults
            let key = instance[keyPath: storageKeyPath].key
            let defaultValue = instance[keyPath: storageKeyPath].defaultValue
            let stored = container.object(forKey: key) as? Value.StoredValue
            return stored.map { Value(storedValue: $0) } ?? defaultValue
        }
        set {
            let container = instance.userDefaults
            let key = instance[keyPath: storageKeyPath].key
            container.set(newValue.storedValue, forKey: key)
            instance.preferencesChangedSubject.send(wrappedKeyPath)
        }
    }
}

@propertyWrapper
struct Preference<Value>: DynamicProperty {
    @ObservedObject private var preferencesObserver: PublisherObservableObject
    private let keyPath: ReferenceWritableKeyPath<Preferences, Value>
    private let preferences: Preferences

    init(_ keyPath: ReferenceWritableKeyPath<Preferences, Value>, preferences: Preferences = .standard) {
        self.keyPath = keyPath
        self.preferences = preferences
        let publisher = preferences
            .preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == keyPath
            }.map { _ in () }
            .eraseToAnyPublisher()
        preferencesObserver = .init(publisher: publisher)
    }

    var wrappedValue: Value {
        get { preferences[keyPath: keyPath] }
        nonmutating set { preferences[keyPath: keyPath] = newValue }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

final class PublisherObservableObject: ObservableObject {
    var subscriber: AnyCancellable?

    init(publisher: AnyPublisher<Void, Never>) {
        subscriber = publisher.sink(receiveValue: { [weak self] _ in
            self?.objectWillChange.send()
        })
    }
}
