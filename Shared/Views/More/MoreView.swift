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
    @AppStorage(STTKeys.incognito) var incognitoMode = false
    @State var cacheSize = Loadable<UInt>.idle
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
            Text("Daisuke Version")
                .badge(STT_BRIDGE_VERSION)
            Text("MS Version")
                .badge("2.0.0")
                .onTapGesture(count: 2) {
                    ToastManager.shared.setToast(toast: .init(displayMode: .alert, type: .image("stt_old", .accentColor), title: "In Our Hearts Forever"))
                }

        } header: {
            Text("Info")
        }

        Section {
            NavigationLink("Social") {
                List {
                    Link(destination: URL(string: "https://ko-fi.com/suwatte")!) {
                        Text("Support on KoFi")
                    }
                    Link(destination: URL(string: "https://www.reddit.com/r/MangaSoup/")!) {
                        Text("Reddit")
                    }
                }
                .navigationTitle("Social")
                
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

            Button {
                KingfisherManager.shared.cache.clearCache()
                ImagePipeline.shared.configuration.dataCache?.removeAll()
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

    func calculateCacheSize() {
        KingfisherManager.shared.cache.calculateDiskStorageSize(completion: { result in

            switch result {
            case let .success(value):
                cacheSize = .loaded(value)
            default: break
            }

        })
    }

    var GeneralSection: some View {
        Section {
            Toggle("Incognito Mode", isOn: $incognitoMode)
            NavigationLink("Appearance & Behaviours") {
                AppearanceView()
            }
            NavigationLink("Progress Trackers") {
                TrackersView()
            }
        } header: {
            Text("General")
        }
    }
}
