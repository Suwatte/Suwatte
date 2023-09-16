//
//  DV+Settings.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-24.
//

import SwiftUI

extension DirectoryViewer {
    struct SettingsSheet: View {
        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false
        var body: some View {
            SmartNavigationView {
                List {
                    Section {
                        Toggle("Show Only Thumbnails", isOn: $showOnlyThumbs)
                        if !showOnlyThumbs {
                            Toggle("Hide Content Insight", isOn: $showTitleOnly)
                        }
                    } header: {
                        Text("Layout")
                    }
                }
                .transition(.opacity)
                .closeButton()
                .navigationTitle("Settings")
                .animation(.default, value: showOnlyThumbs)
                .animation(.default, value: showTitleOnly)
            }
        }
    }
}
