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
        LoadableView(start ,loadable) {
            LoadedTrackerView(tracker: $0)
        }
    }
    
    func start() {
        loadable = .loading
        do {
            loadable = .loaded(try DSK.shared.getContentTracker(id: trackerID))
        } catch {
            loadable = .failed(error)
        }
    }
    
    struct LoadedTrackerView: View {
        let tracker: JSCCT
        var body: some View {
            Group {
                if hasPageLinkResolver {
//                    ContentSourcePageView(source: source)
//                        .navigationTitle("Home")
                } else {
//                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
//                        .navigationTitle("\(source.name) Directory")
//                        .navigationBarTitleDisplayMode(.inline)

                }
            }
        }
        var hasPageLinkResolver: Bool {
            UserDefaults.standard.bool(forKey: STTKeys.PageLinkResolver(tracker.id))
        }
    }
}
