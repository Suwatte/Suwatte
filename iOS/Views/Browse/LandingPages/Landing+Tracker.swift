//
//  Landing+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct TrackerLandingPage: View {
    let trackerID: String
    @State var loadable = Loadable<JSCCT>.idle

    var body: some View {
        LoadableView(load, loadable) {
            LoadedTrackerView(tracker: $0)
        }
    }

    func load() async {
        loadable = .loading
        do {
            let runner = try await DSK.shared.getContentTracker(id: trackerID)
            loadable = .loaded(runner)
        } catch {
            loadable = .failed(error)
        }
    }

    struct LoadedTrackerView: View {
        let tracker: JSCCT
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
