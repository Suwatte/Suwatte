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
            LogSection()
        }
        .navigationBarTitle("App Settings")
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
        @Preference(\.updatesUseCollections) var onlyCheckCollections
        @Preference(\.approvedUpdateCollections) var approvedCollections
        @EnvironmentObject private var model: StateManager
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
                    MultiSelectionView(options: SkipCondition.allCases, selection: SKIP_CONDITIONS) { condition in
                        Text(condition.description)
                    }
                    .buttonStyle(.plain)
                    .navigationTitle("Skip Conditions")
                }

                Toggle("Update Specific Collections", isOn: $onlyCheckCollections)
                    .disabled(!onlyCheckCollections && model.collections.isEmpty)

                if onlyCheckCollections {
                    NavigationLink("Selected Collections") {
                        MultiSelectionView(options: model.collections, selection: SELECTED_COLLECTIONS) { collection in
                            Text(collection.name)
                        }
                        .buttonStyle(.plain)
                        .navigationTitle("Selected Collections")
                    }
                    .transition(.opacity)
                }

            } header: {
                Text("Updates")
            }
            .animation(.default, value: onlyCheckCollections)

            Section {
                // Check Linked
                Toggle("Check Linked Titles", isOn: $checkLinkedOnUpdate)
                Toggle("Update Title Information", isOn: $updateContent)
            } header: {
                Text("Updates")
            }
        }

        var SKIP_CONDITIONS: Binding<Set<SkipCondition>> {
            .init {
                Set(skipConditions)
            } set: { value in
                skipConditions = Array(value)
            }
        }

        var SELECTED_COLLECTIONS: Binding<Set<LibraryCollection>> {
            .init {
                Set(model.collections.filter { approvedCollections.contains($0.id) })
            } set: { selections in
                approvedCollections = Set(selections.map(\.id))
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
        @Preference(\.overrideProvidedReaderMode) var overrideReaderMode

        var body: some View {
            Section {
                Picker("Default Panel Mode", selection: $readerMode) {
                    ForEach(ReadingMode.PanelCases(), id: \.hashValue) { mode in
                        Text(mode.description)
                            .tag(mode)
                    }
                }
                Toggle("Always Use Default Panel Mode", isOn: $overrideReaderMode)

            } header: {
                Text("Reader Panel Mode")
            }

            Section {
                Toggle("Transition Pages", isOn: $forceTransitions)
                Toggle("Haptic Feedback", isOn: $readerHaptics)
            } header: {
                Text("Reader")
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
        @AppStorage(STTKeys.DefaultCollection) var defaultCollection: String = ""
        @AppStorage(STTKeys.DefaultReadingFlag) var defaultFlag = LibraryFlag.unknown
        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection] {
            stateManager.collections
        }

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
        @Preference(\.syncDatabase) private var syncDatabase
        var body: some View {
            Section {
                Toggle("Store on iCloud Drive", isOn: $useCloud)
            } header: {
                Text("On My \(UIDevice.current.model)")
            } footer: {
                Text("When enabled, your comic files will be available across all your devices using iCloud Drive.")
            }
            
            Section {
                Toggle("Sync Library to iCloud", isOn: .constant(false))
                    .disabled(true)
            } header: {
                Text("Database")
            } footer: {
                Text("When enabled, your library will be syned across all your devices using iCloud.")
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

extension SettingsView {
    struct LogSection: View {
        @AppStorage(STTKeys.RunnerDevMode) private var runnerDevMode = false
        @AppStorage(STTKeys.LogAddress) private var logAddress = ""
        var body: some View {
            Section {
                Toggle(isOn: $runnerDevMode) {
                    Text("Enabled")
                }
                if runnerDevMode {
                    HStack {
                        Text("Log Address:")
                        TextFieldView(text: $logAddress, placeholder: "", keyboardType: .URL)
                    }
                }
            } header: {
                Text("Runner Developer Mode")
            }
            .animation(.default, value: runnerDevMode)
        }
    }
}
