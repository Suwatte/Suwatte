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
        DirectoryView<DSKCommon.TrackItem, Cell>(model: .init(runner: tracker, request: request)) { data in
            Cell(data: data, tracker: tracker)
        }
    }
}

// MARK: - Cell

extension ContentTrackerDirectoryView {
    struct Cell: View {
        @State var data: DSKCommon.TrackItem
        let tracker: AnyContentTracker
        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: .init(contentId: data.id, cover: data.cover, title: data.title))
                if let entry = data.entry {
                    ColoredBadge(color: entry.status.color)
                }
            }
            .modifier(TrackerContextModifier(tracker: tracker, item: $data, status: data.entry?.status ?? .CURRENT))
        }
    }
}
