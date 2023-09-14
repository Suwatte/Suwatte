//
//  DV+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

// MARK: - View

struct ContentTrackerDirectoryView: View {
    let tracker: AnyContentTracker
    let request: DSKCommon.DirectoryRequest
    var body: some View {
        DirectoryView(model: .init(runner: tracker, request: request)) { data in
            Cell(data: data, tracker: tracker)
        }
    }
}

// MARK: - Cell

extension ContentTrackerDirectoryView {
    struct Cell: View {
        @State var data: DSKCommon.Highlight
        let tracker: AnyContentTracker
        var body: some View {
            NavigationLink {
                DSKLoadableTrackerView(tracker: tracker, item: data)
            } label: {
                DefaultTile(entry: .init(id: data.id, cover: data.cover, title: data.title))
                    .coloredBadge(data.entry?.status.color)
                    .modifier(TrackerContextModifier(tracker: tracker, item: $data, status: data.entry?.status ?? .CURRENT))
            }
            .buttonStyle(NeutralButtonStyle())
        }
    }
}
