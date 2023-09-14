//
//  PV+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct ContentTrackerPageView: View {
    let tracker: AnyContentTracker
    var link: DSKCommon.PageLink
    var body: some View {
        DSKPageView(model: .init(runner: tracker, link: link)) { item in
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
                .opacity(link.id == "home" ? 1 : 0)
            }
        }
    }

    struct Cell: View {
        let tracker: AnyContentTracker
        @State var item: DSKCommon.Highlight
        var body: some View {
            NavigationLink {
                DSKLoadableTrackerView(tracker: tracker, item: item)
            } label: {
                PageViewTile(runnerID: tracker.id, id: item.id, title: item.title, subtitle: nil, cover: item.cover, additionalCovers: nil, info: nil, badge: nil)
                    .coloredBadge(item.entry?.status.color)
                    .modifier(TrackerContextModifier(tracker: tracker, item: $item, status: item.entry?.status ?? .CURRENT))
            }
            .buttonStyle(NeutralButtonStyle())
        }
    }
}

struct TrackerContextModifier: ViewModifier {
    let tracker: AnyContentTracker
    @Binding var item: DSKCommon.Highlight
    @State var presentEntryFormView = false
    @State var status: DSKCommon.TrackStatus
    @State var presentStatusDialog = false
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
                            let volume = entry.progress.lastReadVolume ?? 0
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
                            presentStatusDialog.toggle()
                        } label: {
                            Label("Start Tracking", systemImage: "pin")
                        }
                    }
                    Divider()
                    if let url = item.webUrl.flatMap ({ URL(string: $0) }) {
                        Link(destination: url) {
                            Label("View on \(tracker.name)", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .animation(.default, value: item.entry)
        .onChange(of: status) { newValue in
            guard newValue != item.entry?.status else { return }
            trackerAction {
                try await tracker.didUpdateStatus(id: item.id, status: newValue)
                let newEntry = try await tracker.getTrackItem(id: item.id)
                await MainActor.run {
                    self.item = newEntry
                }
            }
        }
        .modifier(TrackStatusModifier(title: nil,
                                      tracker: tracker,
                                      contentID: item.id,
                                      alreadyTracking: .constant( item.entry?.status != nil ),
                                      isPresenting: $presentStatusDialog,
                                      callback: { updatedStatus in
            withAnimation {
                status = updatedStatus
            }
        }))
        .hiddenNav(presenting: $presentEntryFormView) {
            DSKLoadableForm(runner: tracker, context: .tracker(id: item.id))
                .navigationTitle(item.title)
        }
    }
}
