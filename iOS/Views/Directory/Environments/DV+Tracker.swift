//
//  DV+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

// MARK: -View
struct ContentTrackerDirectoryView: View {
    let tracker: JSCCT
    let request: DSKCommon.DirectoryRequest
    var body: some View {
        DirectoryView<DSKCommon.TrackItem, Cell>(model: .init(runner: tracker, request: request)) { data in
            Cell(data: data)
        }

    }
}

// MARK: - Cell
extension ContentTrackerDirectoryView {
    struct Cell: View {
        var data: DSKCommon.TrackItem
        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: .init(contentId: data.id, cover: data.cover, title: data.title))
                if let entry = data.entry {
                    ColoredBadge(color: entry.status.color)
                }
            }
        }
    }
}
