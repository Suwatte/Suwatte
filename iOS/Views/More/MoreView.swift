//
//  MoreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import SwiftUI

struct MoreView: View {
    @Preference(\.incognitoMode) var incognitoMode
    var body: some View {
        NavigationView {
            List {
                // TODO: UserProfileHeader
                GeneralSection
                InteractorSection
                DataSection
                AppInformationSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
        }
        .navigationViewStyle(.stack)
    }

    var InteractorSection: some View {
        Section {
            NavigationLink("Installed Runners") {
                InstalledRunnersView()
            }
            NavigationLink("Saved Lists") {
                RunnerListsView()
            }
        } header: {
            Text("Runners")
        }
    }

    @ViewBuilder
    var AppInformationSection: some View {
        Section {
            Text("App Version")
                .badge(Bundle.main.releaseVersionNumber)
            Text("Daisuke Version")
                .badge(STT_BRIDGE_VERSION)
        } header: {
            Text("Info")
        }

        Section {
            Link("Support on KoFi", destination: URL(string: "https://ko-fi.com/mantton")!)
            Link("Support on Patreon", destination: URL(string: "https://patreon.com/mantton")!)
            Link("Discord Server", destination: URL(string: "https://discord.gg/8wmkXsT6h5")!)
            Link("About Suwatte", destination: STTHost.root)
        } header: {
            Text("Links")
        }
    }

    var DataSection: some View {
        Section {
            NavigationLink("Backups") {
                BackupsView()
            }
            NavigationLink("Logs") {
                LogsView()
            }
        } header: {
            Text("Data")
        }
    }

    var GeneralSection: some View {
        Group {
            Section {
                Toggle("Incognito Mode", isOn: $incognitoMode)

                NavigationLink("Settings") {
                    SettingsView()
                }
                NavigationLink("Appearance") {
                    AppearanceView()
                }
            } header: {
                Text("General")
            }
        }
    }
}
