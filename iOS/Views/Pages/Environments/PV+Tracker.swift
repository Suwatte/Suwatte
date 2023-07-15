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
        @State var item : DSKCommon.TrackItem
        var body: some View {
            ZStack(alignment: .topTrailing) {
                PageViewTile(runnerID: tracker.id, id: item.id, title: item.title, cover: item.cover, additionalCovers: nil, info: nil)
                if let color = item.entry?.status.color {
                    ColoredBadge(color: color)
                        .transition(.opacity)
                }
            }
            .modifier(TrackerContextModifier(tracker: tracker, item: $item, status: item.entry?.status ?? .CURRENT))
        }
    }
}


struct TrackerContextModifier: ViewModifier {
    let tracker: JSCCT
    @Binding var item: DSKCommon.TrackItem
    @State var presentEntryFormView = false
    @State var status: DSKCommon.TrackStatus
    
    func trackerAction(_ action: @escaping () async throws -> Void) {
        let prev = item
        Task {
            do {
                try await action()
            } catch {
                self.item = prev // reset of failure
                Logger.shared.error(error, tracker.id)
                ToastManager.shared.error("Failed to Sync")
            }
        }
    }
    
    func body(content: Content) -> some View {
        Group {
            content
                .contextMenu {
                    if let entry = item.entry {
                        HStack {
                            Text("Chapter Progress: \(entry.progress.lastReadChapter.clean)")
                            if let volume = entry.progress.lastReadVolume {
                                Text("Volume Progress: \(volume.clean)")
                            }
                        }
                        Divider()
                        Button {
                            trackerAction {
                                await MainActor.run {
                                    item.entry?.progress.lastReadChapter += 1
                                }
                                try await tracker.didUpdateLastReadChapter(id: item.id, progress: .init(chapter: entry.progress.lastReadChapter + 1, volume: nil))
                            }
                        } label: {
                            Label("Increment Chapter", systemImage: "plus")
                        }
                        Button {
                            let volume =  entry.progress.lastReadVolume ?? 0
                            trackerAction {
                                try await tracker.didUpdateLastReadChapter(id: item.id, progress: .init(chapter: nil, volume: volume + 1))
                            }
                        } label: {
                            Label("Increment Volume", systemImage: "plus")
                        }
                        Divider()
                        Picker("Update Status", selection: $status) {
                            ForEach(DSKCommon.TrackStatus.allCases, id: \.self) { s in
                                Label(s.description, systemImage: s.systemImage)
                                    .tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        Button { presentEntryFormView.toggle() } label: {
                            Label("Edit Tracker Entry", systemImage: "pencil")
                        }
                        
                    } else {
                        Button {
                            trackerAction {
                                try await tracker.beginTracking(id: item.id, status: .CURRENT)
                            }
                        } label: {
                            Label("Start Tracking", systemImage: "pin")
                        }
                    }
                    Divider()
                    if let url = URL(string: item.webUrl) {
                        Link(destination: url) {
                            Label("View on \(tracker.name)", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .animation(.default, value: item.entry)
        .onChange(of: status) { newValue in
            trackerAction {
                await MainActor.run {
                    item.entry?.status = newValue
                }
                try await tracker.didUpdateStatus(id: item.id, status: newValue)
            }
        }
        .hiddenNav(presenting: $presentEntryFormView) {
            TrackerEntryFormView(model: .init(tracker: tracker, id: item.id), title: item.title)
        }
    }
}
