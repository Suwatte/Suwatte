//
//  MoreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Nuke
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
                CacheSection
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
            Text("Daisuke Version")
                .badge(STT_BRIDGE_VERSION)
        } header: {
            Text("Info")
        }
        
        Section {
            Link("Support on KoFi", destination: URL(string: "https://ko-fi.com/mantton")!)
                .badge("\(Image(systemName: "link"))")
            Link("Support on Patreon", destination: URL(string: "https://patreon.com/mantton")!)
                .badge("\(Image(systemName: "link"))")
            Link("Discord Server", destination: URL(string: "https://discord.gg/8wmkXsT6h5")!)
                .badge("\(Image(systemName: "link"))")
            Link("About Suwatte", destination: STTHost.root)
                .badge("\(Image(systemName: "link"))")
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
    
    var CacheSection: some View {
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
