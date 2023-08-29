//
//  PV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct ContentSourcePageView: View {
    let source: AnyContentSource
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
            let identifier = ContentIdentifier(contentId: item.contentId,
                                               sourceId: source.id).id
            Cell(source: source,
                 item: item,
                 inLibrary: model.library.contains(identifier),
                 inReadLater: model.readLater.contains(identifier),
                 hideLibraryBadges: hideLibrayBadges,
                 selection: $selection)
        }
        .task {
            await model.start(source.id)
        }
        .onDisappear(perform: model.stop)
        .animation(.default, value: model.library)
        .animation(.default, value: model.readLater)
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
        let source: AnyContentSource
        @State var item: DSKCommon.Highlight
        @State var inLibrary: Bool
        @State var inReadLater: Bool
        let hideLibraryBadges: Bool
        @Binding var selection: HighlightIdentifier?
        @State var actions: Loadable<[DSKCommon.ContextMenuGroup]> = .idle
        var body: some View {
            PageViewTile(runnerID: source.id,
                         id: item.contentId,
                         title: item.title,
                         subtitle: item.subtitle,
                         cover: item.cover,
                         additionalCovers: item.additionalCovers,
                         info: item.info,
                         badge: inLibrary || inReadLater ? nil : item.badge)
                .coloredBadge(inLibrary ? .accentColor : inReadLater ? .yellow : nil)
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
                        } else {
                            Text("Invalid URL Format for Acquisition Link")
                        }
                    }

                    if source.intents.isContextMenuProvider {
                        buildActions()
                    }
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
            Task {
                let actor = await RealmActor.shared()
                await actor.toggleReadLater(source.id, item.contentId)
                inReadLater.toggle()
            }
        } label: {
            Label(inReadLater ? "Remove from Read Later" : "Add to Read Later",
                  systemImage: inReadLater ? "bookmark.slash" : "bookmark")
        }
    }
}

// MARK: - Context Actions

extension ContentSourcePageView.Cell {
    func loadActions() async {
        actions = .loading
        do {
            let data = try await source.getContextActions(highlight: item)
            actions = .loaded(data)
        } catch {
            Logger.shared.error(error, source.id)
            actions = .loaded([])
        }
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
        LoadableView(loadActions, $actions) { groups in
            ForEach(groups, id: \.key) { group in
                ForEach(group.actions, id: \.key) { action in
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
