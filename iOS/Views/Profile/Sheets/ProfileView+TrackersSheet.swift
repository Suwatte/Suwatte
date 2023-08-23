//
//  ProfileView+TrackersSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import RealmSwift
import SwiftUI

struct TrackerManagementView: View {
    @StateObject var model: ViewModel
    @State var presentSheet = false
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(model.linkedTrackers, id: \.id) { tracker in
                    let loadable = model.dict[tracker.id] ?? .idle
                    VStack {
                        HStack {
//                            STTThumbView(url: tracker.thumbnailURL)
//                                .frame(width: 25, height: 25, alignment: .center)
                            Text(tracker.name)
                                .font(.headline)
                            Spacer()
                        }
                        LoadableView({}, Binding.constant(loadable)) { value in
                            TrackerItemCell(item: value, tracker: tracker, status: value.entry?.status ?? .CURRENT)
                        }
                        .modifier(HistoryView.StyleModifier())
                    }
                    .padding(.all)
                }
            }
            .task {
                await model.prepare()
            }
            .navigationTitle("Trackers")
            .navigationBarTitleDisplayMode(.inline)
            .closeButton()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("\(Image(systemName: "plus"))") {
                        presentSheet.toggle()
                    }
                }
            }
            .fullScreenCover(isPresented: $presentSheet, onDismiss: { Task { await model.prepare() }}) {
                let titles = model.titles
                let trackers = model.unlinkedTrackers
                AddTrackerLinkView(contentId: model.contentID, titles: titles, trackers: trackers)
                    .accentColor(accentColor)
                    .tint(accentColor) // For Invalid Tint on Appear
            }
            .environmentObject(model)
        }
        .toast()
    }
}

extension TrackerManagementView {
    final class ViewModel: ObservableObject {
        typealias TrackItem = DSKCommon.TrackItem

        var contentID: String
        var titles: [String]
        @MainActor @Published var dict: [String: Loadable<TrackItem>] = [:]
        @MainActor @Published var linkedTrackers: [AnyContentTracker] = []
        @MainActor @Published var unlinkedTrackers: [AnyContentTracker] = []
        private var matches: [String: String] = [:]

        init(id: String, _ titles: [String]) {
            contentID = id
            self.titles = titles
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
            let actor = await RealmActor()
            matches = await actor.getTrackerLinks(for: contentID)

            await loadTrackers(Array(matches.keys))

            Task { @MainActor in
                for tracker in linkedTrackers {
                    Task { @MainActor in
                        dict[tracker.id] = .idle
                    }
                }
            }
            await load()
        }

        func load() async {
            let engine = DSK.shared
            await withTaskGroup(of: Void.self) { group in
                for (key, value) in matches {
                    guard let tracker = await engine.getTracker(id: key) else { continue }

                    group.addTask {
                        await self.load(for: tracker, id: value)
                    }
                }
            }
        }

        func load(for tracker: AnyContentTracker, id: String) async {
            do {
                let trackItem = try await tracker.getTrackItem(id: id)
                Task { @MainActor in
                    withAnimation {
                        dict[tracker.id] = .loaded(trackItem)
                    }
                }
            } catch {
                Logger.shared.error(error, tracker.id)
                Task { @MainActor in
                    withAnimation {
                        self.dict[tracker.id] = .failed(error)
                    }
                }
            }
        }

        func unlink(tracker: AnyContentTracker) async {
            let keys = tracker.links
            let actor = await RealmActor()
            await withTaskGroup(of: Void.self, body: { _ in
                for key in keys {
                    await actor.removeLinkKey(for: contentID, key: key)
                }
            })
            matches.removeAll()
            await MainActor.run {
                dict.removeAll()
            }
            await prepare()
        }
    }
}

extension TrackerManagementView {
    struct TrackerItemCell: View {
        @EnvironmentObject var model: ViewModel
        @State var item: DSKCommon.TrackItem
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
                            if let url = URL(string: item.webUrl) {
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
                TrackerEntryFormView(model: .init(tracker: tracker, id: item.id), title: item.title)
            }
        }
    }
}

// MARK: - Add Tracker Views

extension TrackerManagementView {
    struct AddTrackerLinkView: View {
        let contentId: String
        let titles: [String]
        let trackers: [AnyContentTracker]
        @State private var selections: [String: String] = [:]
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .center) {
                        ForEach(trackers, id: \.id) {
                            TrackerResultsSection(tracker: $0, titles: titles, selections: $selections)
                        }
                    }
                }

                .navigationBarTitle("Add Trackers")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
                .toolbar {
                    ToolbarItem {
                        Button("Add") {
                            Task {
                                let actor = await RealmActor()
                                await actor.setTrackerLink(for: contentId, values: selections)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                        .disabled(selections.isEmpty)
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }

    struct TrackerResultsSection: View {
        var tracker: AnyContentTracker
        var titles: [String]
        @State private var loadable: Loadable<[DSKCommon.TrackItem]> = .idle
        @Binding var selections: [String: String]

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
            LoadableView(load, $loadable) { results in
                Group {
                    if results.isEmpty {
                        Text("No Matches")
                            .font(.headline)
                            .fontWeight(.light)
                    } else {
                        ScrollableResultView(results)
                    }
                }
            }
            .frame(alignment: .center)
        }

        // MARK: Views

        func ScrollableResultView(_ results: [DSKCommon.TrackItem]) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(results) { item in
                        Cell(item)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
            }
        }

        func Cell(_ item: DSKCommon.TrackItem) -> some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: .init(contentId: item.id, cover: item.cover, title: item.title))
                    .frame(width: 120, height: 230)
                ColoredBadge(color: .accentColor)
                    .opacity(selections[linkKey] == item.id ? 1 : 0)
            }
            .onTapGesture {
                handleSelection(item.id)
            }
        }

        // MARK: Methods

        var linkKey: String {
            tracker.config?.linkKeys?.first ?? tracker.id
        }

        func load() {
            loadable = .loading
            Task {
                do {
                    let data = try await tracker.getResultsForTitles(titles: titles)
                    loadable = .loaded(data)
                } catch {
                    Logger.shared.error(error, tracker.id)
                    loadable = .failed(error)
                }
            }
        }

        func handleSelection(_ item: String) {
            withAnimation {
                let current = selections[linkKey]
                if current == item { selections.removeValue(forKey: linkKey) }
                else { selections.updateValue(item, forKey: linkKey) }
            }
        }
    }
}
