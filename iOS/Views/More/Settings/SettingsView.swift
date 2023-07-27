//
//  SettingsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-04.
//

import Nuke
import RealmSwift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            OnMyDeviceSection()
            MiscSection()
            LibrarySection()
            ReaderSection()
            UpdatesSection()
            PrivacySection()
            DownloadsSection()
            CacheSection()
            NetworkSection()
            RunnersSection()
        }
        .navigationBarTitle("Settings")
    }
}

// MARK: Misc

extension SettingsView {
    struct MiscSection: View {
        private let options = AppTabs.defaultSettings
        @AppStorage(STTKeys.IntialTabIndex) var InitialSelection = 3
        @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
        var body: some View {
            Section {
                // Initial Opening Tab
                OpeningTab
                Toggle("Open Default Collection", isOn: $openAllOnAppear)

            } header: {
                Text("Tabs")
            }
            .buttonStyle(.plain)
        }

        var OpeningTab: some View {
            Picker("Opening Tab", selection: $InitialSelection) {
                ForEach(options, id: \.rawValue) {
                    Text($0.label())
                        .tag($0.rawValue)
                }
            }
        }
    }
}

extension SettingsView {
    struct UpdatesSection: View {
        @AppStorage(STTKeys.UpdateInterval) var updateInterval: STTUpdateInterval = .oneHour
        @AppStorage(STTKeys.CheckLinkedOnUpdateCheck) var checkLinkedOnUpdate = false
        @AppStorage(STTKeys.UpdateContentData) var updateContent = false
        @Preference(\.skipConditions) var skipConditions
        var body: some View {
            Section {
                // Update Interval
                Picker("Minimum Update Interval", selection: $updateInterval) {
                    ForEach(STTUpdateInterval.allCases, id: \.rawValue) {
                        Text($0.label)
                            .tag($0)
                    }
                }
                NavigationLink("Skip Conditions") {
                    MultiSelectionView(options: SkipCondition.allCases, selection: BINDING) { condition in
                        Text(condition.description)
                    }
                    .buttonStyle(.plain)
                    .navigationTitle("Skip Conditions")
                }

            } header: {
                Text("Updates")
            }

            Section {
                // Check Linked
                Toggle("Check Linked Titles", isOn: $checkLinkedOnUpdate)
                Toggle("Update Title Information", isOn: $updateContent)
            } header: {
                Text("Updates")
            }
        }

        var BINDING: Binding<Set<SkipCondition>> {
            .init {
                Set(skipConditions)
            } set: { value in
                skipConditions = Array(value)
            }
        }
    }
}

extension SettingsView {
    struct PrivacySection: View {
        @AppStorage(STTKeys.BlurWhenAppSwiching) var blurDuringSwitch = false
        var body: some View {
            Section {
                Toggle("Blur During App Switch", isOn: $blurDuringSwitch)
                LibraryAuthenticationToggleView()
            } header: {
                Text("Privacy")
            }
        }
    }
}

extension SettingsView {
    struct NetworkSection: View {
        @Preference(\.userAgent) var userAgent
        var body: some View {
            Section {
                HStack {
                    Text("User Agent:")
                        .foregroundColor(.gray)
                    TextField("", text: $userAgent)
                }
                Button("Clear Cookies", role: .destructive) {
                    HTTPCookieStorage.shared.removeCookies(since: .distantPast)
                }

            } header: {
                Text("Networking")
            }
        }
    }
}

extension SettingsView {
    struct ReaderSection: View {
        @Preference(\.forceTransitions) var forceTransitions
        @Preference(\.enableReaderHaptics) var readerHaptics
        @Preference(\.defaultPanelReadingMode) var readerMode
        var body: some View {
            Section {
                Picker("Default Panel Mode", selection: $readerMode) {
                    ForEach(ReadingMode.PanelCases(), id: \.hashValue) { mode in
                        Text(mode.description)
                            .tag(mode)
                    }
                }
                Toggle("Transition Pages", isOn: $forceTransitions)
                Toggle("Haptic Feedback", isOn: $readerHaptics)
            } header: {
                Text("Reader")
            }
        }
    }
}

extension SettingsView {
    struct RunnersSection: View {
        @AppStorage(STTKeys.HideNSFWRunners) var hideNSFWRunners = false
        @Preference(\.useDirectory) var useDirectory
        var body: some View {
            Section {
                Toggle("Hide NSFW Sources", isOn: $hideNSFWRunners)
                Toggle("Disable Explore Page", isOn: $useDirectory)
            } header: {
                Text("Runners")
            }
        }
    }
}

enum SkipCondition: Int, CaseIterable, Identifiable, UserDefaultsSerializable {
    case INVALID_FLAG, NO_MARKERS, HAS_UNREAD

    var description: String {
        switch self {
        case .HAS_UNREAD: return "Has Unread Chapters"
        case .INVALID_FLAG: return "Flag Not Set to 'Reading'"
        case .NO_MARKERS: return "Not Started"
        }
    }

    var id: Int {
        rawValue
    }
}

extension SettingsView {
    struct LibrarySection: View {
        @AppStorage(STTKeys.AlwaysAskForLibraryConfig) private var alwaysAsk = true
        @ObservedResults(LibraryCollection.self, where: { $0.isDeleted == false }, sortDescriptor: .init(keyPath: "order", ascending: true)) private var collections
        @AppStorage(STTKeys.DefaultCollection) var defaultCollection: String = ""
        @AppStorage(STTKeys.DefaultReadingFlag) var defaultFlag = LibraryFlag.unknown
        var body: some View {
            Section {
                Toggle("Always Prompt", isOn: $alwaysAsk)

                if !alwaysAsk {
                    Picker("Default Collection", selection: .init($defaultCollection, deselectTo: "")) {
                        Text("None")
                            .tag("")
                        ForEach(collections) {
                            Text($0.name)
                                .tag($0.id)
                        }
                    }
                    .transition(.slide)
                }

                if !alwaysAsk {
                    Picker("Default Reading Flag", selection: $defaultFlag) {
                        ForEach(LibraryFlag.allCases) {
                            Text($0.description)
                                .tag($0)
                        }
                    }
                    .transition(.slide)
                }
            } header: {
                Text("Library")
            }
            .animation(.default, value: alwaysAsk)
        }
    }
}

extension SettingsView {
    struct CacheSection: View {
        var body: some View {
            Section {
                Button(role: .destructive) {
                    Task {
                        ImagePipeline.shared.cache.removeAll()
                        ToastManager.shared.info("Image Cache Cleared!")
                    }
                } label: {
                    HStack {
                        Text("Clear Image Cache")
                        Spacer()
                        Image(systemName: "photo.fill.on.rectangle.fill")
                    }
                }
                Button(role: .destructive) {
                    Task {
                        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
                        URLCache.shared.removeAllCachedResponses()
                        ToastManager.shared.info("Network Cache Cleared!")
                    }
                } label: {
                    HStack {
                        Text("Clear Network Cache")
                        Spacer()
                        Image(systemName: "network")
                    }
                }
            } header: {
                Text("Cache")
            }
        }
    }
}

// MARK: On My Device

extension SettingsView {
    struct OnMyDeviceSection: View {
        @Preference(\.useCloudForLocal) var useCloud
        var body: some View {
            Section {
                Toggle("Store on iCloud Drive", isOn: $useCloud)
            } header: {
                Text("On My \(UIDevice.current.model)")
            } footer: {
                Text("When enabled, your library will be available across all your devices using iCloud Drive.")
            }
        }
    }
}

public extension Binding where Value: Equatable {
    init(_ source: Binding<Value>, deselectTo value: Value) {
        self.init(get: { source.wrappedValue },
                  set: { source.wrappedValue = $0 == source.wrappedValue ? value : $0 })
    }
}

extension SettingsView {
    struct DownloadsSection: View {
        @Preference(\.archiveSourceDownload) var archive
        var body: some View {
            Section {
                Toggle("Archive Download", isOn: $archive)
            } header: {
                Text("Chapter Downloads")
            } footer: {
                Text("If enabled, suwatte will compress downloaded chapters and store them as CBZ files.")
            }
        }
    }
}
