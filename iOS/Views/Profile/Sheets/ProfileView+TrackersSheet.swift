//
//  ProfileView+TrackersSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import NavigationSearchBar
import RealmSwift
import SwiftUI

struct TrackerManagementView: View {
    @StateObject var model: ViewModel
    @State var presentSheet = false
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

    var body: some View {
        ScrollView {
            ForEach(model.linkedTrackers, id: \.id) { tracker in
                IndividualTrackerView(tracker: tracker)
                    .padding(.all)
            }
        }
        .task {
            await model.prepare()
        }
        .transition(.opacity)
        .animation(.default, value: model.linkedTrackers.count)
        .navigationTitle("Trackers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("\(Image(systemName: "plus"))") {
                    presentSheet.toggle()
                }
            }
        }
        .fullScreenCover(isPresented: $presentSheet, onDismiss: { Task { await model.prepare() }}) {
            let title = model.title
            let trackers = model.unlinkedTrackers
            AddTrackerLinkView(query: title, contentId: model.contentID, trackers: trackers)
                .accentColor(accentColor)
                .tint(accentColor) // For Invalid Tint on Appear
        }
        .environmentObject(model)
    }
}

extension TrackerManagementView {
    struct IndividualTrackerView: View {
        let tracker: AnyContentTracker
        @State private var thumbnailURL: String?
        @EnvironmentObject private var model: ViewModel
        var body: some View {
            VStack {
                HStack {
                    ZStack {
                        if let url = thumbnailURL.flatMap({ URL(string: $0) }) {
                            STTThumbView(url: url)
                        } else {
                            STTThumbView()
                        }
                    }
                    .frame(width: 25, height: 25, alignment: .center)
                    .cornerRadius(7)

                    Text(tracker.name)
                        .font(.headline)
                    Spacer()
                }
                ZStack {
                    if let contentID = model.matches[tracker.id] {
                        ItemCell(tracker: tracker, contentID: contentID)

                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .modifier(HistoryView.StyleModifier())
            }
            .task {
                await load()
            }
            .animation(.default, value: thumbnailURL)
        }

        func load() async {
            let object = await RealmActor.shared().getFrozenRunner(tracker.id)
            await MainActor.run {
                withAnimation {
                    thumbnailURL = object?.thumbnail ?? ""
                }
            }
        }
    }
}

extension TrackerManagementView {
    struct ItemCell: View {
        let tracker: AnyContentTracker
        let contentID: String
        @State private var loadable: Loadable<DSKCommon.Highlight> = .idle

        var body: some View {
            LoadableView(tracker.id, load, $loadable) { item in
                TrackerItemCell(item: item, tracker: tracker, status: item.entry?.status ?? .CURRENT)
            }
        }

        func load() async throws -> DSKCommon.Highlight {
            try await tracker.getTrackItem(id: contentID)
        }
    }
}

extension TrackerManagementView {
    final class ViewModel: ObservableObject {
        typealias TrackItem = DSKCommon.Highlight

        var contentID: String
        var title: String
        @MainActor @Published var linkedTrackers: [AnyContentTracker] = []
        @MainActor @Published var unlinkedTrackers: [AnyContentTracker] = []
        var matches: [String: String] = [:]

        init(id: String, _ title: String) {
            contentID = id
            self.title = title
        }

        func loadTrackers(_ keys: [String]) async {
            let data = await DSK.shared.getActiveTrackers()

            await MainActor.run {
                self.linkedTrackers = data
                    .filter { keys.contains($0.id) }
                self.unlinkedTrackers = data
                    .filter { !keys.contains($0.id) }
            }
        }

        func prepare() async {
            let actor = await RealmActor.shared()
            matches = await actor.getTrackerLinks(for: contentID)

            await loadTrackers(Array(matches.keys))
        }

        func unlink(tracker: AnyContentTracker) async {
            let keys = tracker.links
            await RealmActor.shared().removeLinkKeys(for: tracker.id, keys: keys)

            await MainActor.run {
                linkedTrackers.removeAll(where: { $0.id == tracker.id })
                unlinkedTrackers.append(tracker)
            }
        }
    }
}

extension TrackerManagementView {
    struct TrackerItemCell: View {
        @EnvironmentObject var model: ViewModel
        @State var item: DSKCommon.Highlight
        let tracker: AnyContentTracker
        @State var status: DSKCommon.TrackStatus
        private let size = 140.0
        @State var presentEntryFormView = false
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

        var body: some View {
            HStack {
                BaseImageView(url: URL(string: item.cover))
                    .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                    .scaledToFit()
                    .cornerRadius(5)
                    .shadow(radius: 3)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                        Spacer()
                        Menu {
                            if let entry = item.entry {
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
                                    ForEach(DSKCommon.TrackStatus.allCases, id: \.hashValue) { s in
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
                                        await model.prepare()
                                    }
                                } label: {
                                    Label("Start Tracking", systemImage: "pin")
                                }
                            }
                            Divider()
                            Divider()
                            Button(role: .destructive) {
                                Task {
                                    await model.unlink(tracker: tracker)
                                }
                            } label: {
                                Label("Remove Link", systemImage: "trash")
                            }
                            if let url = URL(string: item.webUrl ?? "") {
                                Link(destination: url) {
                                    Label("View on \(tracker.name)", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .rotationEffect(.degrees(90))
                                .contentShape(Rectangle())
                                .padding(.leading)
                        }
                    }
                    if let entry = item.entry {
                        HStack {
                            Image(systemName: entry.status.systemImage)
                            Text(entry.status.description)
                        }
                        .foregroundColor(entry.status.color)
                        .font(.subheadline)

                        Text("Progress: ")
                            .font(.subheadline)
                            .fontWeight(.light)
                            +
                            Text("\(entry.progress.lastReadChapter.clean) / \(entry.progress.maxAvailableChapter?.clean ?? "-")")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                    } else {
                        Text("Not Tracking")
                            .font(.subheadline.weight(.light))
                    }

                    Spacer()
                }
                Spacer()
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
                DSKLoadableForm(runner: tracker, context: .tracker(id: item.id))
            }
        }
    }
}

// MARK: - Add Tracker Views

extension TrackerManagementView {
    struct AddTrackerLinkView: View {
        @State var query: String
        @State var debouncedQuery: String

        let contentId: String
        let trackers: [AnyContentTracker]
        @State private var selections: [String: String] = [:]
        @Environment(\.presentationMode) var presentationMode

        init(query: String, contentId: String, trackers: [AnyContentTracker]) {
            self.query = query
            debouncedQuery = query
            self.contentId = contentId
            self.trackers = trackers
        }

        var body: some View {
            SmartNavigationView {
                ScrollView {
                    VStack(alignment: .center) {
                        ForEach(trackers, id: \.id) {
                            TrackerResultsSection(tracker: $0, title: $debouncedQuery, selections: $selections)
                        }
                    }
                }
                .navigationBarTitle("Add Trackers")
                .navigationBarTitleDisplayMode(.inline)
                .animation(.default, value: query)
                .closeButton()
                .navigationSearchBar(text: $query,
                                     options: [
                                         .hidesNavigationBarDuringPresentation: false,
                                     ])
                .task(id: query) {
                    try? await Task.sleep(seconds: 0.45)
                    if Task.isCancelled { return }

                    debouncedQuery = query
                }
                .toolbar {
                    ToolbarItem {
                        Button("Add") {
                            Task {
                                let actor = await RealmActor.shared()
                                await actor.setTrackerLink(for: contentId, values: selections)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                        .disabled(selections.isEmpty)
                    }
                }
            }
        }
    }

    struct TrackerResultsSection: View {
        var tracker: AnyContentTracker
        @Binding var title: String
        @State private var loadable: Loadable<[DSKCommon.Highlight]> = .idle
        @Binding var selections: [String: String]
        @State var key = ""
        var body: some View {
            // Header
            VStack {
                HStack {
//                    STTThumbView(url: tracker.thumbnailURL)
//                        .frame(width: 25, height: 25, alignment: .center)
                    Text(tracker.name)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
            }

            // Resullts
            LoadableView(tracker.id, load, $loadable) { results in
                ZStack {
                    if results.isEmpty {
                        Text("No Matches")
                            .font(.headline)
                            .fontWeight(.light)
                    } else {
                        ScrollableResultView(results)
                    }
                }
            }
            .onChange(of: title) { _ in
                loadable = .idle
            }
            .frame(alignment: .center)
            .task {
                key = tracker.config?.linkKeys?.first ?? tracker.id
            }
        }

        // MARK: Views

        func ScrollableResultView(_ results: [DSKCommon.Highlight]) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(results, id: \.hashValue) { item in
                        Cell(item)
                            .frame(width: 120, height: 230)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity)
        }

        func Cell(_ item: DSKCommon.Highlight) -> some View {
            Button {
                handleSelection(item.id)
            } label: {
                DefaultTile(entry: .init(id: item.id, cover: item.cover, title: item.title))
                    .coloredBadge(selections[key] == item.id ? .accentColor : nil)
            }
            .buttonStyle(NeutralButtonStyle())
            .contentShape(Rectangle())
        }

        func load() async throws -> [DSKCommon.Highlight] {
            try await tracker.getResultsForTitles(titles: [title])
        }

        func handleSelection(_ item: String) {
            withAnimation {
                if selections[key] != nil, item == selections[key] {
                    selections[key] = nil
                } else {
                    selections[key] = item
                }
            }
        }
    }
}
