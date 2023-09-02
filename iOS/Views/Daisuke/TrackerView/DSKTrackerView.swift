//
//  DSKTrackerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-31.
//

import SwiftUI

struct DSKLoadableTrackerView: View {
    let tracker: AnyContentTracker
    let item: DSKCommon.TrackItem
    @State var loadable: Loadable<DSKCommon.FullTrackItem> = .idle
    var body: some View {
        LoadableView(load, $loadable) { value in
            DSKTrackerView(tracker: tracker, content: value)
        }
        .navigationTitle(item.title)
    }
    
    func load() async throws {
        let data = try await tracker.getFullInformation(id: item.id)
        loadable = .loaded(data)
    }
}



struct DSKTrackerView: View {
    let tracker: AnyContentTracker
    let content: DSKCommon.FullTrackItem
    var body: some View {
        ScrollView {
            VStack {
                
            }
            .padding(.horizontal)
        }
    }
}
