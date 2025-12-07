//
//  SourceDownloadQueueView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-26.
//

import SwiftUI

struct SourceDownloadQueueView: View {
    @StateObject private var model: ViewModel = .init()
    @State var activeDownload: SourceDownload?
    @State var activeDownloadState: SDM.DownloadState?
    var body: some View {
        ZStack {
            ListView
                .opacity(!model.data.isEmpty || activeDownload != nil && model.initialDataFetchComplete ? 1 : 0)
            NoResultsView()
                .opacity(model.data.isEmpty && activeDownload == nil && model.initialDataFetchComplete ? 1 : 0)
            ProgressView()
                .opacity(model.data.isEmpty && activeDownload == nil && !model.initialDataFetchComplete ? 1 : 0)
        }
        .navigationBarTitle("Queue")
        .task {
            await model.watch()
        }
        .onDisappear(perform: model.stop)
        .onReceive(SDM.shared.activeDownload) { value in
            Task {
                await didRecievePub(value)
            }
        }
        .animation(.default, value: model.data)
        .animation(.default, value: model.isWorking)
        .animation(.default, value: model.initialDataFetchComplete)
        .animation(.default, value: activeDownload)
        .animation(.default, value: activeDownloadState)
    }

    var ListView: some View {
        List {
            // Active View
            Section {
                ActiveDownloadView(download: activeDownload, downloadState: activeDownloadState)
            } header: {
                Text("Active")
            }
            .headerProminence(.increased)

            ForEach(model.data, id: \.first?.content?.id) { group in
                let content = group.first?.content ?? StoredContent()
                ContentGroup(content: content, entries: group)
            }
        }
    }

    struct NoResultsView: View {
        var body: some View {
            VStack(spacing: 3.5) {
                Text("ᕙ(‾̀◡‾́)ᕗ")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("your queue is empty!")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
            .foregroundColor(.gray)
        }
    }
}

// MARK: Content Grou

typealias SDQV = SourceDownloadQueueView
extension SDQV {
    struct ContentGroup: View {
        let content: StoredContent
        let entries: [SourceDownload]

        var body: some View {
            Section {
                Header(content: content, downloads: entries)
                ForEach(entries) {
                    Cell(download: $0)
                }
            }
        }
    }
}

// MARK: Header

extension SDQV {
    struct Header: View {
        let content: StoredContent
        let downloads: [SourceDownload]
        var body: some View {
            HStack(alignment: .top, spacing: 5) {
                STTImageView(url: URL(string: content.cover), identifier: content.ContentIdentifier)
                    .frame(width: 60, height: 1.5 * 60)
                    .cornerRadius(7)
                VStack(alignment: .leading) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text("^[\(downloads.count) Chapter](inflect: true) Queued")
                        .font(.footnote)
                        .fontWeight(.light)
                }
                Spacer()
                HeaderActionButton(ids: ids, statuses: statuses)
            }
        }

        var ids: [String] {
            downloads
                .map(\.id)
        }

        var statuses: [DownloadStatus] {
            downloads
                .map(\.status)
                .distinct()
        }
    }
}

// MARK: Cell

extension SDQV {
    struct Cell: View {
        let download: SourceDownload
        var body: some View {
            ChapterListTile(chapter: download.chapter!.toThreadSafe(),
                            isCompleted: false,
                            isNewChapter: false,
                            progress: nil,
                            download: download.status,
                            isLinked: false,
                            showLanguageFlag: false,
                            showDate: false,
                            isBookmarked: false)
                .modifier(CellActions(id: download.id, status: download.status))
        }
    }
}

// MARK: Cell Actions

extension SDQV {
    struct CellActions: ViewModifier {
        let id: String
        let status: DownloadStatus
        private let manager = SDM.shared
        func body(content: Content) -> some View {
            content
                .swipeActions {
                    Button("Cancel", role: .destructive) {
                        Task {
                            await manager.cancel(ids: [id])
                        }
                    }
                    switch status {
                    case .paused:
                        Button("Resume") {
                            Task {
                                await manager.resume(ids: [id])
                            }
                        }
                        .tint(.blue)
                    case .failing:
                        Button("Retry") {
                            Task {
                                await manager.resume(ids: [id])
                            }
                        }
                        .tint(.yellow)
                    default: EmptyView()
                    }
                }
        }
    }
}

// MARK: Header Action

extension SDQV {
    struct HeaderActionButton: View {
        let ids: [String]
        let statuses: [DownloadStatus]
        var body: some View {
            Menu {
                if hasFailing {
                    Button {
                        Task {
                            await SDM.shared.resume(ids: ids)
                        }
                    } label: {
                        Label("Retry Failing", systemImage: "arrow.counterclockwise")
                    }
                }

                if hasPaused {
                    Button {
                        Task {
                            await SDM.shared.resume(ids: ids)
                        }
                    } label: {
                        Label("Resume Paused", systemImage: "play")
                    }
                }

                if hasQueued {
                    Button {
                        Task {
                            await SDM.shared.pause(ids: ids)
                        }
                    } label: {
                        Label("Pause Queued", systemImage: "pause")
                    }
                }

                if hasHighlightedState {
                    Divider()
                }
                Button(role: .destructive) {
                    Task {
                        await SDM.shared.cancel(ids: ids)
                    }
                } label: {
                    Label("Cancel All", systemImage: "xmark")
                }

            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.headline)
            }
        }

        var hasFailing: Bool {
            statuses.contains(.failing)
        }

        var hasPaused: Bool {
            statuses.contains(.paused)
        }

        var hasQueued: Bool {
            statuses.contains(.queued)
        }

        var hasHighlightedState: Bool {
            hasFailing || hasPaused || hasQueued
        }
    }
}

// MARK: Active Chapter View

extension SDQV {
    func didRecievePub(_ info: (String, SDM.DownloadState)?) async {
        guard model.initialDataFetchComplete else { return }
        guard let info else {
            // Reset
            withAnimation {
                activeDownload = nil
                activeDownloadState = nil
            }
            return
        }

        let id = info.0
        let state = info.1

        if id == activeDownload?.id {
            withAnimation {
                activeDownloadState = state
            }

            return
        }
        let actor = await RealmActor.shared()
        let target = await actor.getActiveDownload(id)

        guard let target else {
            withAnimation {
                activeDownload = nil
                activeDownloadState = nil
            }
            return
        }

        withAnimation {
            activeDownload = target
            activeDownloadState = state
        }
    }
}

extension SDQV {
    struct ActiveDownloadView: View {
        var download: SourceDownload?
        var downloadState: SDM.DownloadState?
        var body: some View {
            ZStack {
                if let download, let downloadState {
                    Cell(download, state: downloadState)
                } else {
                    NoActiveDownloadView
                }
            }
            .transition(.slide)
            .frame(maxWidth: .infinity)
            .frame(alignment: .center)
        }

        var NoActiveDownloadView: some View {
            VStack(spacing: 3.5) {
                Text("⁽⁽ଘ( ˊωˋ )ଓ⁾⁾")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("no active download")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
            .foregroundColor(.gray)
        }

        func CellHeader(_ content: StoredContent, _: StoredChapter) -> some View {
            HStack(alignment: .center, spacing: 5) {
                HStack(alignment: .top) {
                    STTImageView(url: URL(string: content.cover), identifier: content.ContentIdentifier)
                        .frame(width: 60, height: 1.5 * 60)
                        .cornerRadius(7)
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                Spacer()
                StateView(downloadState!)
            }
        }

        func StateView(_ state: SDM.DownloadState) -> some View {
            ZStack {
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
            .transition(.opacity)
            .frame(width: 30, height: 30, alignment: .center)
        }

        @ViewBuilder
        func Cell(_ download: SourceDownload, state _: SDM.DownloadState) -> some View {
            let content = download.content!
            let chapter = download.chapter!

            VStack {
                CellHeader(content, chapter)
                ChapterListTile(chapter: chapter.toThreadSafe(),
                                isCompleted: false,
                                isNewChapter: false,
                                progress: nil,
                                download: nil,
                                isLinked: false,
                                showLanguageFlag: false,
                                showDate: false,
                                isBookmarked: false)
            }
        }
    }
}
