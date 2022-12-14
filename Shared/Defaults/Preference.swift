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
    var novelFont = "Avenir-Regular"

    @UserDefault(STTKeys.NonSelectiveSync)
    var nonSelectiveSync = false

    @UserDefault(STTKeys.SelectiveUpdates)
    var selectiveUpdates = false
}

@propertyWrapper
struct UserDefault<Value> {
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
            return container.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            let container = instance.userDefaults
            let key = instance[keyPath: storageKeyPath].key
            container.set(newValue, forKey: key)
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
