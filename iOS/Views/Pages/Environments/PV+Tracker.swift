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
        DSKPageView(model: .init(runner: tracker, key: pageKey)) { item in
            Cell(item)
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
    
    @ViewBuilder
    func Cell( _ item : DSKCommon.PageSectionItem) -> some View {
        ZStack(alignment: .topTrailing) {
            PageViewTile(entry: item, runnerID: tracker.id)
            if let color = badgeColor(item.trackStatus ,item.badgeColor){
                ColoredBadge(color: color)
                    .transition(.opacity)
            }
        }
    }
    
    func badgeColor(_ status: DSKCommon.TrackStatus? , _ badge: String?) -> Color? {
        if let status {
            return status.color
        }
        if let badge {
            return Color.init(hex: badge)
        }
        
        return nil
    }
}
