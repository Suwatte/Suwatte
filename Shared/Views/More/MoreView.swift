//
//  MoreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Kingfisher
import Nuke
import SwiftUI

struct MoreView: View {
    @Preference(\.incognitoMode) var incognitoMode
    @State var cacheSize = Loadable<UInt>.idle
    @State var showEasterEgg = false
    var body: some View {
        NavigationView {
            List {
                // TODO: UserProfileHeader
                GeneralSection
                InteractorSection
                DataSection
                AppInformationSection
            }
            .navigationTitle("More")
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
                .badge(Bundle.main.releaseVersionNumber)
                .onTapGesture(count: 2) {
                    withAnimation {
                        showEasterEgg.toggle()
                    }
                }
            Text("Daisuke Version")
                .badge(STT_BRIDGE_VERSION)
            if showEasterEgg {
                Text("MangaSoup Version")
                    .badge("2.0.0")
            }

        } header: {
            Text("Info")
        }

        Section {
            NavigationLink("Social") {
                List {
                    Section {
                        Link(destination: URL(string: "https://ko-fi.com/mantton")!) {
                            Text("Support on KoFi")
                        }
                        Link(destination: URL(string: "https://patreon.com/mantton")!) {
                            Text("Support on Patreon")
                        }
                    }

                    Section {
                        Link(destination: URL(string: "https://discord.gg/PnxPBNwkj2")!) {
                            Text("Discord Server")
                        }
                        Link(destination: URL(string: "https://twitter.com/ceresmir")!) {
                            Text("Twitter")
                        }
                    }
                }
                .navigationTitle("Social")
                .buttonStyle(.plain)
            }
            Link("About Suwatte", destination: STTHost.root)
                .buttonStyle(.plain)
        } footer: {
            Text("A Mantton Project")
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
            Button {
                KingfisherManager.shared.cache.clearCache()
                ImagePipeline.shared.configuration.dataCache?.removeAll()
                ToastManager.shared.info("Image Cache Cleared!")
            } label: {
                HStack {
                    Text("Clear Image Cache")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
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
                NavigationLink("Trackers") {
                    TrackersView()
                }
            } header: {
                Text("General")
            }
        }
    }
}
