//
//  MoreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import SwiftUI

struct MoreView: View {
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
            
            SettingsView()
        }
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
                .badge("\(Bundle.main.releaseVersionNumber ?? "")b\(Bundle.main.buildVersionNumber ?? "")")
            Text("Daisuke Version")
                .badge(STT_BRIDGE_VERSION)
        } header: {
            Text("Info")
        }

        Section {
            Link("Discord Server", destination: URL(string: "https://discord.gg/8wmkXsT6h5")!)
                .badge("\(Image(systemName: "arrow.up.right.circle"))")
            Link("About Suwatte", destination: STTHost.root)
                .badge("\(Image(systemName: "arrow.up.right.circle"))")

        } header: {
            Text("Links")
        }
        .buttonStyle(.plain)

        Section {
            Link("Support on KoFi", destination: URL(string: "https://ko-fi.com/mantton")!)
                .badge("\(Image(systemName: "arrow.up.right.circle"))")

            Link("Support on Patreon", destination: URL(string: "https://patreon.com/mantton")!)
                .badge("\(Image(systemName: "arrow.up.right.circle"))")

        } header: {
            Text("Support")
        }
        .buttonStyle(.plain)
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
                NavigationLink("App Settings") {
                    SettingsView()
                }
                NavigationLink("Content Settings") {
                    ContentSettingsView()
                }
                NavigationLink("Appearance") {
                    AppearanceView()
                }
                NavigationLink("Experimental Features") {
                    ExperimentalFeaturesView()
                }
            } header: {
                Text("General")
            }
        }
    }
}
