//
//  ContentSettingsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import SwiftUI

struct ContentSettingsView: View {
    @Preference(\.incognitoMode) var incognitoMode
    @AppStorage(STTKeys.GlobalHideNSFW) var hideNSFW = false
    @Preference(\.blackListProviderOnSourceLevel) var blacklistOnSourceLevel
    @Preference(\.trackerAutoSync) var trackerAutoSync

    var body: some View {
        List {
            Section {
                Toggle("Incognito Mode", isOn: $incognitoMode)
            } footer: {
                Text("Your search and reading progress will not be saved when enabled.")
            }

            Section {
                Toggle("Hide NSFW Sources & Titles", isOn: $hideNSFW)
            } header: {
                Text("Content Rating")
            }

            Section {
                NavigationLink("Content Languages") {
                    ContentLanguageSettingsView()
                }
            } header: {
                Text("Content Languages")
            }

            Section {
                Toggle("Hide Providers on a Source Basis", isOn: $blacklistOnSourceLevel)
            } header: {
                Text("Chapter Providers")
            } footer: {
                Text("If disabled, hidden providers will only apply to the title being set.")
            }

            Section {
                Toggle("Auto Sync", isOn: $trackerAutoSync)
            } header: {
                Text("Trackers")
            } footer: {
                Text("If enabled, sources which provide valid tracking ID's will be synced automatically with your installed trackers.")
            }
        }
        .navigationTitle("Content Settings")
    }
}
