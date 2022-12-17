//
//  AppearanceView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import SwiftUI

struct AppearanceView: View {
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.COMPACT
    @AppStorage(STTKeys.incognito) var incognitoMode = false
    @AppStorage(STTKeys.GridItemsPerRow_P) var IPRP = 2
    @AppStorage(STTKeys.GridItemsPerRow_LS) var IPRLS = 6
    @AppStorage(STTKeys.AppAccentColor) var appAccentColor: Color = .sttDefault

    var body: some View {
        Form {
            Section {
                ColorPicker("Accent Color", selection: $appAccentColor)
            } header: {
                Text("Colors")
            }
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

            
            
        }
        .buttonStyle(.plain)
        .navigationTitle("Appearance")
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


enum STTUpdateInterval : Int, CaseIterable {
    case oneHour, twoHours, sixHours, twelveHours
    case oneDay, oneWeek, twoWeeks, oneMonth
}


extension STTUpdateInterval {
    

    var label: String {
        switch self {
            case .oneHour:
                return "1 Hour"
            case .twoHours:
                return "2 Hours"
            case .sixHours:
                return "6 Hours"
            case .twelveHours:
                return "12 Hours"
            case .oneDay:
                return "1 Day"
            case .oneWeek:
                return "1 Week"
            case .twoWeeks:
                return "2 Weeks"
            case .oneMonth:
                return "1 Month"
        }
    }
}


extension STTUpdateInterval {
    
    var interval: Double  {
        switch self {
            case .oneHour:
                return 3600
            case .twoHours:
                return 3600 * 2
            case .sixHours:
                return 3600 * 6
            case .twelveHours:
                return 3600 * 12
            case .oneDay:
                return 3600 * 24
            case .oneWeek:
                return 3600 * 24 * 7
            case .twoWeeks:
                return 3600 * 24 * 7 * 2
            case .oneMonth:
                return 3600 * 24 * 7 * 4
        }
    }
}
