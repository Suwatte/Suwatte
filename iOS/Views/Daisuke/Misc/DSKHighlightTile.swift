//
//  DSKHighlightTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-10.
//

import SwiftUI

struct DSKHighlightTile: View {
    @State var data: DSKCommon.Highlight
    var source: AnyContentSource
    @State var inLibrary: Bool
    @State var inReadLater: Bool
    @Binding var selection: HighlightIdentifier?
    let hideLibraryBadges: Bool
    @State private var presentLink = false
    @State private var actions: Loadable<[DSKCommon.ContextMenuGroup]> = .idle
    private var sourceID: String {
        source.id
    }

    var body: some View {
        PageViewTile(runnerID: source.id,
                     id: data.id,
                     title: data.title,
                     subtitle: data.subtitle,
                     cover: data.cover,
                     additionalCovers: data.additionalCovers,
                     info: data.info,
                     badge: inLibrary || inReadLater ? nil : data.badge)
            .coloredBadge(inLibrary ? .accentColor : inReadLater ? .yellow : nil)
            .contextMenu {
                if source.ablityNotDisabled(\.disableLibraryActions) {
                    ReadLaterButton
                    Divider()
                }
                if let acqStr = data.acquisitionLink {
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
            .hiddenNav(presenting: $presentLink) {
                if let link = data.link {
                    PageLinkView(link: link, title: data.title, runnerID: sourceID)
                } else {
                    EmptyView()
                }
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

// MARK: - Default Actions

extension DSKHighlightTile {
    var ReadLaterButton: some View {
        Button {
            Task {
                let actor = await RealmActor.shared()
                await actor.toggleReadLater(source.id, data.id)
                inReadLater.toggle()
            }
        } label: {
            Label(inReadLater ? "Remove from Read Later" : "Add to Read Later",
                  systemImage: inReadLater ? "bookmark.slash" : "bookmark")
        }
    }
}

// MARK: - Context Actions

extension DSKHighlightTile {
    func loadActions() async {
        actions = .loading
        do {
            let data = try await source.getContextActions(highlight: data)
            actions = .loaded(data)
        } catch {
            Logger.shared.error(error, source.id)
            actions = .loaded([])
        }
    }

    func didTriggerActions(key: String) {
        Task {
            do {
                try await source.didTriggerContextActon(highlight: data, key: key)

                guard source.intents.canRefreshHighlight else { return }
                let data = try await source.getHighlight(highlight: data)

                Task { @MainActor in
                    self.data = data
                }
            } catch {
                Logger.shared.error(error, source.id)
            }
        }
    }

    @ViewBuilder
    func buildActions() -> some View {
        LoadableView(loadActions, $actions) { groups in
            ForEach(groups, id: \.id) { group in
                ForEach(group.actions, id: \.id) { action in
                    if action.displayAsLabel {
                        Text(action.title)
                    } else {
                        Button(role: action.isDestructive ? .destructive : .none) {
                            didTriggerActions(key: action.id)
                        } label: {
                            if let systemImage = action.systemImage {
                                Label(action.title, systemImage: systemImage)
                            } else {
                                Text(action.title)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Handle Tap

extension DSKHighlightTile {
    func handleTap() {
        let isStreamable = data.streamable ?? false

        guard isStreamable else {
            navigate()
            return
        }

        guard source.intents.providesReaderContext else {
            StateManager.shared.alert(title: "Bad Configuation", message: "\(source.name) stated that this title can be streamed but has not implemented the 'provideReaderContext' method.")
            return
        }

        handleReadContent()
    }

    func navigate() {
        if data.link != nil {
            presentLink.toggle()
        } else {
            selection = (source.id, data)
        }
    }
}

// MARK: - Handle Read

extension DSKHighlightTile {
    func handleReadContent() {
        StateManager.shared.stream(item: data, sourceId: source.id)
    }
}

// MARK: - Download

extension DSKHighlightTile {
    func download(_ url: URL) {
        let title = data.title
        let defaultRequest = URLRequest(url: url)
        Task {
            do {
                let thumbnailURL = URL(string: data.cover)
                var thumbnailRequest: URLRequest?
                if let thumbnailURL {
                    if source.intents.imageRequestHandler {
                        thumbnailRequest = try (await source.willRequestImage(imageURL: thumbnailURL)).toURLRequest()
                    }
                }

                let downloadRequest = try await source.overrrideDownloadRequest(url.absoluteString)?.toURLRequest() ?? defaultRequest
                let download = DirectoryViewer.DownloadManager.DownloadObject(url: url, request: downloadRequest, title: title, thumbnailReqeust: thumbnailRequest)
                DirectoryViewer.DownloadManager.shared.addToQueue(download)
                ToastManager.shared.info("Downloading!")
            } catch {
                Logger.shared.error(error, source.id)
                ToastManager.shared.error(error)
                Task { @MainActor in
                    StateManager.shared.alert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}
