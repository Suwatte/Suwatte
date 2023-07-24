//
//  PV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct ContentSourcePageView: View {
    let source: JSCCS
    var link: DSKCommon.PageLink
    @StateObject private var model = ContentSourceDirectoryView.ViewModel()
    @StateObject var manager = LocalAuthManager.shared
    @Preference(\.protectContent) var protectContent
    @State private var selection: HighlightIdentifier?

    var pageKey: String {
        link.key
    }

    var body: some View {
        DSKPageView<DSKCommon.Highlight, Cell>(model: .init(runner: source, link: link)) { item in
            Cell(source: source,
                 item: item,
                 inLibrary: model.library.contains(item.contentId),
                 inReadLater: model.readLater.contains(item.contentId),
                 hideLibraryBadges: hideLibrayBadges,
                 selection: $selection)
        }
        .task {
            model.start(source.id)
        }
        .onDisappear(perform: model.stop)
        .modifier(InteractableContainer(selection: $selection))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    AllTagsView(source: source)
                } label: {
                    Image(systemName: "tag")
                }
                .opacity(pageKey == "home" && source.intents.hasTagsView ? 1 : 0)
                NavigationLink {
                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
                        .navigationTitle("Search \(source.name)")
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .opacity(pageKey == "home" ? 1 : 0)
            }
        }
    }

    var hideLibrayBadges: Bool {
        protectContent && manager.isExpired
    }

    struct Cell: View {
        let source: JSCCS
        @State var item: DSKCommon.Highlight
        @State var inLibrary: Bool
        @State var inReadLater: Bool
        let hideLibraryBadges: Bool
        @Binding var selection: HighlightIdentifier?

        var body: some View {
            PageViewTile(runnerID: source.id,
                         id: item.contentId,
                         title: item.title,
                         subtitle: item.subtitle,
                         cover: item.cover,
                         additionalCovers: item.additionalCovers,
                         info: item.info,
                         badge: item.badge)
                .contextMenu {
                    if source.ablityNotDisabled(\.disableLibraryActions) {
                        ReadLaterButton
                        Divider()
                    }
                    if let acqStr = item.acquisitionLink {
                        if let url = URL(string: acqStr) {
                            Button {
                                download(url)
                            } label: {
                                Label("Download", systemImage: "externaldrive.badge.plus")
                            }
                        }
                    } else {
                        Text("Invalid URL Format for Acquisition Link")
                    }
                    buildActions()
                }
                .onTapGesture {
                    handleTap()
                }
        }

        func badgeColor() -> Color? {
            let libraryBadge = (inLibrary || inReadLater) && !hideLibraryBadges
            if libraryBadge {
                return inLibrary ? .accentColor : .yellow
            }
            return nil
        }
    }
}

// MARK: - Default Actions

extension ContentSourcePageView.Cell {
    var ReadLaterButton: some View {
        Button {
            if inReadLater {
                DataManager.shared.removeFromReadLater(source.id, content: item.contentId)
            } else {
                DataManager.shared.addToReadLater(source.id, item.contentId)
            }
        } label: {
            Label(inReadLater ? "Remove from Read Later" : "Add to Read Later", systemImage: inReadLater ? "bookmark.slash" : "bookmark")
        }
    }
}

// MARK: - Context Actions

extension ContentSourcePageView.Cell {
    func getActions() -> [[DSKCommon.ContextMenuAction]] {
        guard source.intents.isContextMenuProvider else {
            return []
        }
        do {
            let actions = try source.getContextActions(highlight: item)
            return actions
        } catch {
            Logger.shared.error(error, source.id)
        }

        return []
    }

    func didTriggerActions(key: String) {
        Task {
            do {
                try await source.didTriggerContextActon(highlight: item, key: key)

                guard source.intents.canRefreshHighlight else { return }
                let data = try await source.getHighlight(highlight: item)

                Task { @MainActor in
                    item = data
                }
            } catch {
                Logger.shared.error(error, source.id)
            }
        }
    }

    @ViewBuilder
    func buildActions() -> some View {
        let actions = getActions()
        if !actions.isEmpty {
            ForEach(actions, id: \.hashValue) { group in
                Divider()
                ForEach(group, id: \.hashValue) { action in
                    if action.displayAsLabel {
                        Text(action.label)
                    } else {
                        Button(role: action.isDestructive ? .destructive : .none) {
                            didTriggerActions(key: action.key)
                        } label: {
                            if let systemImage = action.systemImage {
                                Label(action.label, systemImage: systemImage)
                            } else {
                                Text(action.label)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Handle Tap

extension ContentSourcePageView.Cell {
    func handleTap() {
        let isStreamable = item.streamable ?? false

        guard isStreamable else {
            selection = (source.id, item)
            return
        }

        guard source.intents.providesReaderContext else {
            StateManager.shared.alert(title: "Bad Configuation", message: "\(source.name) stated that this title can be streamed but has not implemented the 'provideReaderContext' method.")
            return
        }

        handleReadContent()
    }
}

// MARK: - Handle Read

extension ContentSourcePageView.Cell {
    func handleReadContent() {
        StateManager.shared.stream(item: item, sourceId: source.id)
    }
}

// MARK: - Download

extension ContentSourcePageView.Cell {
    func download(_ url: URL) {
        let title = item.title
        let defaultRequest = URLRequest(url: url)
        Task {
            do {
                let thumbnailURL = URL(string: item.cover)
                var thumbnailRequest: URLRequest? = nil
                if let thumbnailURL {
                    if source.intents.imageRequestHandler {
                        thumbnailRequest = try (await source.willRequestImage(imageURL: thumbnailURL)).toURLRequest()
                    }
                }

                let downloadRequest = try await source.overrrideDownloadRequest(url.absoluteString)?.toURLRequest() ?? defaultRequest
                let download = DirectoryViewer.DownloadManager.DownloadObject(url: url, request: downloadRequest, title: title, thumbnailReqeust: thumbnailRequest)
                DirectoryViewer.DownloadManager.shared.addToQueue(download)
            } catch {
                Logger.shared.error(error, source.id)
                Task { @MainActor in
                    StateManager.shared.alert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}
