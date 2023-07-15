//
//  PV+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI


struct ContentTrackerPageView: View {
    let tracker: JSCCT
    var pageKey: String = "home"
    var body: some View {
        DSKPageView<DSKCommon.TrackItem, Cell>(model: .init(runner: tracker, key: pageKey)) { item in
            Cell(tracker: tracker, item: item)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    ContentTrackerDirectoryView(tracker: tracker, request: .init(page: 1))
                        .navigationTitle("Search \(tracker.name)")
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .opacity(pageKey == "home" ? 1 : 0)
            }
        }
    }
    
    struct Cell: View {
        let tracker: JSCCT
        let item : DSKCommon.TrackItem
        var body: some View {
            ZStack(alignment: .topTrailing) {
                PageViewTile(runnerID: tracker.id, id: item.id, title: item.title, cover: item.cover, additionalCovers: nil, info: nil)
                if let color = item.entry?.status.color {
                    ColoredBadge(color: color)
                        .transition(.opacity)
                }
            }
        }
    }
}
