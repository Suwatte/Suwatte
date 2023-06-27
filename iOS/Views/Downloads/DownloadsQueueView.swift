//
//  DownloadsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI

struct DownloadsQueueView: View {
    @ObservedResults(ICDMDownloadObject.self, where: { $0.status != .completed }, sortDescriptor: .init(keyPath: "dateAdded", ascending: true)) var downloads
    @State var contentHash: [String: StoredContent] = [:]
    @State var activeDownloadState: ICDM.ActiveDownloadState?
    var body: some View {
        Group {
            if downloads.isEmpty {
                IdleView
                    .transition(.opacity)
            } else {
                OngoingView
                    .transition(.slide)
            }
        }
        .animation(.default, value: downloads)
        .navigationTitle("Download Queue")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ICDM.shared.activeDownloadPublisher) { value in
            guard let value = value else {
                activeDownloadState = nil
                return
            }

            activeDownloadState = value.1
        }
    }

    var OngoingView: some View {
        List {
            // Current Active
            if let download = currentActiveDownload {
                CurrentActiveView(download)
                    .animation(.default, value: currentActiveDownload)
            }
            QueuedSection
            PausedSection
            FailingSection
        }
        .listStyle(.plain)
    }

    var IdleView: some View {
        Text("No Active Downloads")
            .font(.headline)
            .fontWeight(.light)
            .foregroundColor(.gray)
    }
}

// MARK: Queued

extension DownloadsQueueView {
    var queuedCount: Int {
        downloads.filter { $0.status == .queued }.count
    }

    @ViewBuilder
    var QueuedSection: some View {
        let entries = downloads.filter { $0.status == .idle || $0.status == .queued }
        let grouped = GroupedByEntry(Array(entries))
        let sortedKeys = SortedKeys(grouped)

        Section {
            ForEach(sortedKeys) { key in
                if let entry = DataManager.shared.getStoredContent(str(key.split(separator: "|").first!), str(key.split(separator: "|").last!)) {
                    EntryCell(entry: entry, downloads: grouped[key]!)
                }
            }
        } header: {
            Text("Queued")
        }
        .headerProminence(.increased)
    }
}

// MARK: Active

extension DownloadsQueueView {
    func CurrentActiveView(_ download: ICDMDownloadObject) -> some View {
        Section {
            if let chapter = download.chapter, let entry = DataManager.shared.getStoredContent(chapter.sourceId, chapter.contentId) {
                HStack(alignment: .center) {
                    BaseImageView(url: URL(string: entry.cover))
                        .frame(width: 75, height: 75 * 1.5, alignment: .center)
                        .cornerRadius(7)

                    VStack(alignment: .leading) {
                        Text(entry.title)
                            .font(.headline)
                            .fontWeight(.light)
                        Text(chapter.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    Spacer()
                    Group {
                        if let state = activeDownloadState {
                            switch state {
                            case .fetchingImages:
                                Image(systemName: "icloud.and.arrow.down")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray)
                                    .shimmering()
                            case .finalizing:
                                Image(systemName: "folder")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.green.opacity(0.5))
                                    .shimmering()
                            case let .downloading(progress: progress):
                                ProgressCircle(progress: progress)
                            }
                        }
                    }
                    .frame(width: 40, height: 40, alignment: .center)
                }
                .padding(.vertical, 7)
            }
        } header: {
            HStack {
                Text("Active Download")
                Spacer()
                Button("Pause") {
                    ICDM.shared.pause(ids: [download._id])
                }
            }
        }
        .headerProminence(.increased)
    }

    var currentActiveDownload: ICDMDownloadObject? {
        downloads.first(where: { $0.status == .active })
    }
}

// MARK: Failing

extension DownloadsQueueView {
    var failingCount: Int {
        downloads.filter { $0.status == .failing }.count
    }

    @ViewBuilder
    var FailingSection: some View {
        let entries = downloads.filter { $0.status == .failing }
        let grouped = GroupedByEntry(Array(entries))
        let sortedKeys = SortedKeys(grouped)
        Section {
            ForEach(sortedKeys, id: \.self) { key in
                if let entry = DataManager.shared.getStoredContent(str(key.split(separator: "|").first!), str(key.split(separator: "|").last!)) {
                    EntryCell(entry: entry, downloads: grouped[key]!)
                }
            }
        } header: {
            HStack {
                Text("Failing")
                Spacer()
                if failingCount >= 1 {
                    Button("Retry All") {
                        ICDM.shared.resume(ids: entries.map { $0._id })
                    }
                }
            }
        }.headerProminence(.increased)
    }

    func str(_ s: Substring) -> String {
        String(s)
    }
}

// MARK: Paused

extension DownloadsQueueView {
    var pausedCount: Int {
        downloads.filter { $0.status == .paused }.count
    }

    @ViewBuilder
    var PausedSection: some View {
        let entries = downloads.filter { $0.status == .paused }
        let grouped = GroupedByEntry(Array(entries))
        let sortedKeys = SortedKeys(grouped)
        Section {
            ForEach(sortedKeys, id: \.self) { key in
                if let entry = DataManager.shared.getStoredContent(str(key.split(separator: "|").first!), str(key.split(separator: "|").last!)) {
                    EntryCell(entry: entry, downloads: grouped[key]!)
                }
            }
        } header: {
            HStack {
                Text("Paused")
                Spacer()
                if pausedCount >= 1 {
                    Button("Resume All") {
                        ICDM.shared.resume(ids: entries.map { $0._id })
                    }
                }
            }
        }.headerProminence(.increased)
    }
}

extension DownloadsQueueView {
    func GroupedByEntry(_ entries: [ICDMDownloadObject]) -> [String: [ICDMDownloadObject]] {
        let dict = Dictionary(grouping: entries, by: { $0.getIdentifiers().source + "|" + $0.getIdentifiers().content })

        return dict
    }

    func SortedKeys(_ dict: [String: [ICDMDownloadObject]]) -> [String] {
        Array(dict.keys.sorted(by: { dict[$0]![0].dateAdded < dict[$1]![0].dateAdded }))
    }
}

// MARK: Cell

extension DownloadsQueueView {
    fileprivate typealias ListTile = ChapterListTile

    @ViewBuilder
    func EntryCell(entry: StoredContent, downloads: [ICDMDownloadObject]) -> some View {
        let chapters = downloads.sorted(by: { $0.dateAdded < $1.dateAdded }).compactMap { $0.chapter }
        Section {
            ForEach(chapters) { chapter in
                if let download = downloads.first(where: { $0._id == chapter.id }) {
                    DefaultTile(chapter: chapter, download: download)
                } else {
                    EmptyView()
                }
            }
        } header: {
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.title)
                        .font(.headline)
                    Text((try? SourceManager.shared.getContentSource(id: entry.sourceId).name) ?? "Unrecognized Source")
                        .font(.subheadline)
                        .fontWeight(.light)
                }
                Spacer()
                Menu {
                    if let status = downloads.first?.status {
                        switch status {
                        case .failing:
                            Button("Retry All") {
                                ICDM.shared.resume(ids: downloads.map { $0._id })
                            }
                        case .paused:
                            Button("Resume All") {
                                ICDM.shared.resume(ids: downloads.map { $0._id })
                            }
                        default: EmptyView()
                        }

                        Button("Cancel All", role: .destructive) {
                            ICDM.shared.cancel(ids: downloads.map { $0._id })
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25, alignment: .center)
                        .padding(.vertical)
                }
            }
        }
    }

    @ViewBuilder
    func DefaultTile(chapter: StoredChapter, download: ICDMDownloadObject) -> some View {
        let manager = ICDM.shared
        let id = download._id
        ListTile(chapter: chapter, isCompleted: false, isNewChapter: false, download: download)
            .swipeActions {
                Button("Cancel", role: .destructive) {
                    manager.cancel(ids: [id])
                }

                switch download.status {
                case .paused:
                    Button("Resume") {
                        manager.resume(ids: [id])
                    }
                    .tint(.blue)
                case .failing:
                    Button("Retry") {
                        manager.resume(ids: [id])
                    }
                    .tint(.yellow)
                default: EmptyView()
                }
            }
    }
}
