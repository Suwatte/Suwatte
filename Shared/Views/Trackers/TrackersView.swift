//
//  TrackersView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import SwiftUI

struct TrackersView: View {
    var body: some View {
        List {
            NavigationLink(destination: AnilistView.Gateway()) {
                MSLabelView(title: "Anilist", imageName: "anilist")
            }

            NavigationLink(destination: Text("Placeholder")) {
                MSLabelView(title: "MyAnimeList", imageName: "mal")
            }
        }
        .navigationTitle("Tracking")
    }
}
