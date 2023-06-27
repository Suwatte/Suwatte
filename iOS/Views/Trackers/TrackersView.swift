//
//  TrackersView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import SwiftUI

struct TrackersView: View {
    @Preference(\.nonSelectiveSync) var nonSelectiveSync
    @Preference(\.includeNSFWInAnilistSearchResult) var showNSFWContentInSearch
    @Preference(\.blurNSFWContentInSearch) var blurNSFWContentInSearch
    @State var presentAlert = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: AnilistView.Gateway()) {
                    MSLabelView(title: "Anilist", imageName: "anilist")
                }

//                NavigationLink(destination: Text("Placeholder")) {
//                    MSLabelView(title: "MyAnimeList", imageName: "mal")
//                }
            }

            Section {
                Toggle(isOn: $nonSelectiveSync) {
                    Text("Auto Track \(Image(systemName: "info.circle"))")
                        .onTapGesture {
                            presentAlert.toggle()
                        }
                }

                Toggle(isOn: $showNSFWContentInSearch) {
                    Text("Include NSFW Content In Search Results")
                }

                Toggle(isOn: $blurNSFWContentInSearch) {
                    Text("Blur NSFW Content In Search Results")
                }

            } header: {
                Text("Settings")
            }
            .alert("Auto Track", isPresented: $presentAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Suwatte Will Begin Tracking Previously Untracked Titles Automatically")
            }
        }
        .navigationTitle("Tracking")
    }
}
