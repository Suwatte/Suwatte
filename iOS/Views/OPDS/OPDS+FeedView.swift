//
//  OPDS+FeedView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import ASCollectionView
import R2Shared
import ReadiumOPDS
import RealmSwift
import SwiftUI

extension Feed: Identifiable, Equatable {
    public static func == (lhs: R2Shared.Feed, rhs: R2Shared.Feed) -> Bool {
        lhs.id == rhs.id
    }
}

extension OPDSView {
    struct LoadableFeedView: View {
        @EnvironmentObject var client: OPDSClient
        var url: String
        @State var loadable: Loadable<Feed> = .idle

        var body: some View {
            LoadableView(nil, load, $loadable) { feed in
                FeedView(feed: feed)
                    .refreshable {
                        loadable = .idle
                    }
            }
            .environmentObject(client)
        }

        func load() async throws -> R2Shared.Feed {
            try await client.getFeed(url: url)
        }
    }
}

// MARK: Feed View

extension OPDSView.LoadableFeedView {
    struct FeedView: View {
        var feed: Feed
        var body: some View {
            ZStack {
                if feed.publications.isEmpty {
                    NavigationSection(feed: feed)
                } else {
                    PublicationSection(feed: feed)
                }
            }

            .navigationBarTitle(feed.metadata.title)
        }
    }
}

// MARK: Type Alias

private typealias Target = OPDSView.LoadableFeedView.FeedView

extension Target {
    struct ObjectLink<Content: View>: View {
        @EnvironmentObject var client: OPDSClient
        var link: R2Shared.Link
        var label: (R2Shared.Link) -> Content

        init(link: R2Shared.Link, @ViewBuilder _ label: @escaping (R2Shared.Link) -> Content) {
            self.link = link
            self.label = label
        }

        var body: some View {
            NavigationLink {
                OPDSView.LoadableFeedView(url: link.href)
                    .environmentObject(client)
            } label: {
                label(link)
            }
        }
    }
}

// MARK: Navigation

extension Target {
    struct NavigationSection: View {
        var feed: Feed
        var body: some View {
            List {
                Section {
                    ForEach(feed.navigation, id: \.href) { nav in
                        ObjectLink(link: nav) { link in
                            Label(link.title ?? link.href, systemImage: "folder")
                        }
                    }
                } header: {
                    Text("Navigation")
                }
            }
        }
    }
}

// MARK: Publication

extension Target {
    struct PublicationSection: View {
        var feed: Feed

        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @StateObject var manager: DirectoryViewer.DownloadManager = .shared
        @State var chapter: ThreadSafeChapter?
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        var body: some View {
            ASCollectionView(section: AS_SECTION)
                .layout(createCustomLayout: {
                    DynamicGridLayout(75)
                }, configureCustomLayout: { layout in
                    layout.invalidateLayout()
                })
                .alwaysBounceVertical()
                .animateOnDataRefresh(true)
                .fullScreenCover(item: $chapter) { chapter in
                    ReaderGateWay(title: chapter.title ?? "",
                                  readingMode: .defaultPanelMode,
                                  chapterList: [chapter],
                                  openTo: chapter)
                }
                .animation(.default, value: chapter)
        }

        var AS_SECTION: ASSection<Int> {
            return ASSection(id: 0, data: feed.publications, dataID: \.metadata.identifier) { publication, _ in
                ZStack(alignment: .topTrailing) {
                    Tile(publication: publication, chapter: $chapter)
                    if let url = publication.acquisitionLink.flatMap({ URL(string: $0) }) {
                        if let download = manager.downloads.first(where: { $0.url == url }) {
                            TileOverlay(download: download)
                        }
                    }
                }
            }
        }

        struct TileOverlay: View {
            @ObservedObject var download: DirectoryViewer.DownloadManager.DownloadObject
            var body: some View {
                ZStack(alignment: .topTrailing) {
                    switch download.status {
                    case .failing:
                        ColoredBadge(color: .red)
                    case .active:
                        ColoredBadge(color: .green)
                    case .queued:
                        ColoredBadge(color: .gray)
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

import Alamofire
import NukeUI

extension Target {
    struct Tile: View {
        var publication: Publication
        var tileStyle = TileStyle.SEPARATED
        @EnvironmentObject var client: OPDSClient
        @StateObject private var image = FetchImage()
        @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
        @State var presentDialog = false
        @State var presentAlert = false
        @Binding var chapter: ThreadSafeChapter?

        var thumbnailRequest: URLRequest? {
            var headers = HTTPHeaders()
            if let auth = client.authHeader {
                headers.add(name: "Authorization", value: auth)
            }
            return try? URLRequest(url: publication.thumbnailURL ?? "", method: HTTPMethod.get, headers: headers)
        }

        var acquisitionRequest: URLRequest? {
            var headers = HTTPHeaders()
            if let auth = client.authHeader {
                headers.add(name: "Authorization", value: auth)
            }
            return try? URLRequest(url: publication.acquisitionLink ?? "", method: HTTPMethod.get, headers: headers)
        }

        var body: some View {
            GeometryReader { proxy in
                let imageWidth = proxy.size.width
                let imageHeight = imageWidth * 1.5
                VStack(alignment: .leading, spacing: 5) {
                    ZStack {
                        if let image = image.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .transition(.opacity)
                        } else {
                            Color.gray.opacity(0.25)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: imageWidth, height: imageHeight)
                    .background(Color.fadedPrimary)
                    .cornerRadius(5)

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(publication.metadata.title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack {
                            if publication.isStreamable {
                                Image(systemName: "dot.radiowaves.up.forward")
                                    .foregroundColor(color)
                                    .font(.footnote.weight(.bold))
                            }

                            if let pages = publication.streamLink?.properties["count"] as? String ?? publication.metadata.numberOfPages?.description {
                                Text(pages + " Pages")
                                    .font(.footnote.weight(.thin))
                            }
                        }
                    }

                    .frame(alignment: .topLeading)
                }
            }
            .onAppear {
                if let request = thumbnailRequest {
                    image.transaction = .init(animation: .easeInOut(duration: 0.25))
                    image.load(.init(urlRequest: request))
                }
            }
            .onDisappear { image.reset() }
            .animation(.default, value: image.isLoading)
            .animation(.easeInOut(duration: 0.25), value: image.image)
            .onTapGesture {
                presentDialog.toggle()
            }
            .alert("Info", isPresented: $presentAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(PublicationDescription)
            })

            .confirmationDialog("Actions", isPresented: $presentDialog) {
                if publication.isStreamable {
                    Button("Info") {
                        presentAlert.toggle()
                    }

                    if let link = publication.acquisitionLink.flatMap({ URL(string: $0) }) {
                        Button("Download") {
                            guard let request = acquisitionRequest else {
                                return
                            }
                            let title = publication.metadata.title
                            let download = DirectoryViewer.DownloadManager.DownloadObject(url: link, request: request, title: title, thumbnailReqeust: thumbnailRequest)
                            DirectoryViewer.DownloadManager.shared.addToQueue(download)
                        }
                    }
                    if publication.isStreamable && !publication.isProtected && !publication.isRestricted {
                        Button("Stream") {
                            handleStreamSelection(publication: publication)
                        }
                    }
                }
            }
        }

        var PublicationDescription: String {
            let title = publication.metadata.title
            let other = publication.metadata.description ?? ""

            return "\(title)\n\(other)"
        }

        func handleStreamSelection(publication: Publication) {
            Task {
                let actor = await RealmActor.shared()
                do {
                    try await actor.savePublication(publication, client.id)
                    chapter = try publication.toReadableChapter(clientID: client.id)
                } catch {
                    ToastManager.shared.error(error)
                    Logger.shared.error(error, "OPDS")
                }
            }
        }
    }
}
