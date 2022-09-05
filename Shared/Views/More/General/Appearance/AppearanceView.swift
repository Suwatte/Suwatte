//
//  AppearanceView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import SwiftUI

struct AppearanceView: View {
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.COMPACT
    @AppStorage(STTKeys.IntialTabIndex) var InitialSelection = 3
    @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
    @AppStorage(STTKeys.incognito) var incognitoMode = false
    @AppStorage(STTKeys.GridItemsPerRow_P) var IPRP = 2
    @AppStorage(STTKeys.GridItemsPerRow_LS) var IPRLS = 6
    let options = AppTabs.defaultSettings
    var body: some View {
        List {
            Section {
                Stepper(value: $IPRP, in: 2 ... 10) {
                    FieldLabel(primary: "Potrait", secondary: IPRP.description)
                }
                Stepper(value: $IPRLS, in: 4 ... 15) {
                    FieldLabel(primary: "Landscape", secondary: IPRLS.description)
                }
            } header: {
                Text("Items Per Row")
            }
            Section {
                NavigationLink {
                    List {
                        ForEach(TileStyle.allCases, id: \.hashValue) { entry in
                            SelectionLabel(label: entry.description, isSelected: entry == tileStyle, action: { tileStyle = entry })
                        }
                    }
                    .buttonStyle(.plain)
                    .navigationTitle("Tile Style")
                    .onChange(of: tileStyle) { _ in
                        NotificationCenter.default.post(name: .init(STTKeys.TileStyle), object: nil)
                    }
                } label: {
                    STTLabelView(title: "Tile Style", label: tileStyle.description)
                }

            } header: {
                Text("Tiles")
            }

            // Initial Tab
            Section {
                NavigationLink {
                    List {
                        ForEach(Array(zip(options.indices, options)), id: \.0) { index, option in
                            SelectionLabel(label: option.label(), isSelected: index == InitialSelection, action: { InitialSelection = index })
                        }
                    }
                    .buttonStyle(.plain)
                    .navigationTitle("Opening Tab")
                } label: {
                    STTLabelView(title: "Opening Tab", label: options[InitialSelection].label())
                }

            } header: {
                Text("Tab")
            }
            .buttonStyle(.plain)

            // Open All Titles On Libary Appear
            Section {
                Toggle("Open Default Collection", isOn: $openAllOnAppear)
                LibraryAuthenticationToggleView()
            } header: {
                Text("Library")
            }
        }
        .buttonStyle(.plain)
        .navigationTitle("Appearance & Behaviours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LibraryAuthenticationToggleView: View {
    @Preference(\.protectContent) var protectContent
    @AppStorage(STTKeys.TimeoutDuration) var timeout = LocalAuthManager.TimeoutDuration.immediately
    var body: some View {
        PrivacySection
    }

    @ViewBuilder
    var PrivacySection: some View {
        Toggle("Protect Content", isOn: $protectContent)
            .onChange(of: timeout, perform: LocalAuthManager.shared.handleTimeoutChange(_:))
            .animation(.default, value: protectContent)

        if protectContent {
            SelectionView(selection: PrivacyTimeOutSelection, options: PrivacyOptionsMapped, title: "Timeout")
                .animation(.default, value: protectContent)
        }
    }

    var PrivacyOptionsMapped: [SelectionView.Option] {
        LocalAuthManager.TimeoutDuration.allCases.map { .init(label: $0.description, value: $0.rawValue.description) }
    }

    var PrivacyTimeOutSelection: Binding<SelectionView.Option> {
        func getter() -> SelectionView.Option {
            return .init(label: timeout.description, value: timeout.rawValue.description)
        }

        func setter(_ option: SelectionView.Option) {
            if LocalAuthManager.shared.isExpired {
                LocalAuthManager.shared.authenticate()
            } else {}
            timeout = LocalAuthManager.TimeoutDuration(rawValue: Int(option.value) ?? 0)!
        }

        return .init(get: getter, set: setter)
    }
}
