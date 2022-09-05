//
//  DaisukeRunnerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import SwiftUI

struct DaisukeContentSourceView: View {
    @ObservedObject var source: DaisukeEngine.ContentSource
    var body: some View {
        List {
            // TODO: Source Info

            Section {
                NavigationLink("Preferences") {
                    PreferencesView()
                        .environmentObject(source)
                        .navigationTitle("Preferences")
                }
            }
            if let info = (source.info as? DSK.ContentSource.ContentSourceInfo), let authMethod = info.authMethod {
                AuthSection(authMethod: authMethod, canSync: info.canSync)
            }
        }
        .navigationTitle(source.name)
        .environmentObject(source)
    }
}
