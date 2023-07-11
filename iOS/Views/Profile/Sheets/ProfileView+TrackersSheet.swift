//
//  ProfileView+TrackersSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import RealmSwift
import SwiftUI


struct TrackerManagementView: View  {
    @StateObject var model: ViewModel
    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(model.trackers, id: \.id) { tracker in
                    let loadable = model.dict[tracker.id]!
                    VStack {
                        HStack {
                            STTThumbView(url: tracker.thumbnailURL)
                                .frame(width: 25, height: 25, alignment: .center)
                            Text(tracker.name)
                                .font(.headline)
                            Spacer()
                        }
                        LoadableView({}, loadable) { value in
                            TrackerItemCell(item: value, tracker: tracker)
                        }
                        .modifier(HistoryView.StyleModifier())
                        
                    }
                    .padding(.all)
                }
            }
            .task {
                model.prepare()
                await model.load()
            }
            .navigationTitle("Trackers")
            .navigationBarTitleDisplayMode(.inline)
            .closeButton()
        }
        .toast()
        
    }
    
}

extension TrackerManagementView {
    final class ViewModel: ObservableObject {
        typealias TrackItem = DSKCommon.TrackItem

        private var contentID: String
        @Published var dict: [String: Loadable<TrackItem>] = [:]
        
        private var matches: [String: String] = [:]
        var trackers: [JSCCT] {
            dict
                .keys
                .compactMap({ DSK.shared.getTracker(id: $0) })
                .sorted(by: \.name, descending: false)
        }
        init(id: String) {
            self.contentID = id
        }
        
        func prepare() {
            matches = DataManager.shared.getTrackerLinks(for: contentID)
            
            for (key, _) in matches {
                guard DSK.shared.getTracker(id: key) != nil else { continue }
                dict[key] = .idle
            }
        }
        
        func load() async {
            await withTaskGroup(of: Void.self, body: { group in
                for (key, value) in matches {
                    print(key, value)
                    guard let tracker = DSK.shared.getTracker(id: key) else { continue }
                    Task { @MainActor in
                        self.dict[key] = .loading
                    }
                    
                    group.addTask {
                        do {
                            let trackItem = try await tracker.getTrackItem(id: value)
                            await MainActor.run {
                                withAnimation {
                                    self.dict[key] = .loaded(trackItem)
                                }
                            }
                        } catch {
                            Logger.shared.error(error, tracker.id)
                            await MainActor.run {
                                withAnimation {
                                    self.dict[key] = .failed(error)
                                }
                            }
                        }
                    }
                }
                
                for await _ in group {
                    
                }
            })
        }
        
        
    }
}

extension TrackerManagementView {
    struct TrackerItemCell: View {
        @State var item: DSKCommon.TrackItem
        let tracker: JSCCT
        @State var status: DSKCommon.TrackStatus = .CURRENT
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
                BaseImageView(url: URL(string: item.thumbnail))
                    .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                    .scaledToFit()
                    .cornerRadius(5)
                    .shadow(radius: 3)
                

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.title)
                            .font(.headline.weight(.semibold))
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
                                    let volume =  entry.progress.lastReadVolume ?? 0
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
                                Divider()
                                
                            } else {
                                Button("Start Tracking") {
                                    trackerAction {
                                        try await tracker.beginTracking(id: item.id, status: .CURRENT)
                                    }
                                }
                            }
                            
                            if let url = URL(string: item.webUrl) {
                                Link(destination: url) {
                                    Label("View on \(tracker.name)", systemImage: "square.and.arrow.up")
                                }
                            }
                                                       
                        } label: {
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
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

extension Anilist.Media {
    func toSearchResult() -> Anilist.SearchResult {
        .init(id: id, type: type, status: status, isAdult: isAdult, title: .init(userPreferred: title.userPreferred), coverImage: .init(large: coverImage.large, extraLarge: coverImage.extraLarge, color: coverImage.color), genres: genres, countryOfOrigin: countryOfOrigin)
    }
}
