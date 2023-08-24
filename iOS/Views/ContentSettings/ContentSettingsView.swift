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
        }
        .navigationTitle("Content Settings")
    }
}
