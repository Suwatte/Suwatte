//
//  Landing+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct TrackerLandingPage: View {
    let trackerID: String
    @State var loadable = Loadable<AnyContentTracker>.idle

    var body: some View {
        LoadableView(load, $loadable) {
            LoadedTrackerView(tracker: $0)
        }
    }

    func load() async throws {
        loadable = .loading
        let runner = try await DSK.shared.getContentTracker(id: trackerID)
        loadable = .loaded(runner)
    }

    struct LoadedTrackerView: View {
        let tracker: AnyContentTracker
        var body: some View {
            Group {
                if tracker.intents.pageLinkResolver {
//                    ContentSourcePageView(source: source)
                } else {
//                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
//                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}
