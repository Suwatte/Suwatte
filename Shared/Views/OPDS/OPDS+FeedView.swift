//
//  OPDS+FeedView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import ASCollectionView
import Kingfisher
import R2Shared
import ReadiumOPDS
import SwiftUI

extension OPDSView {
    struct LoadableFeedView: View {
        @EnvironmentObject var client: OPDSClient
        var url: String
        @State var loadable: Loadable<Feed> = .idle

        var body: some View {
            LoadableView(loadable: loadable) {
                ProgressView()
                    .onAppear {
                        handleLoad()
                    }
            } _: {
                ProgressView()
            } _: { error in
                ErrorView(error: error, action: handleLoad)
            } _: { value in
                FeedView(feed: value)
                    .refreshable {
                        await action()
                    }
            }

            .environmentObject(client)
        }

        func handleLoad() {
            loadable = .loading
            Task { @MainActor in
                await action()
            }
        }

        func action() async {
            do {
                let feed = try await client.getFeed(url: url)
                withAnimation {
                    loadable = .loaded(feed)
                }
            } catch {
                withAnimation {
                    loadable = .failed(error)
                }
            }
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
        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait
        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        @State var chapter: StoredChapter?
        var body: some View {
            ASCollectionView(section: AS_SECTION)

                .layout(createCustomLayout: {
                    SuwatteDefaultGridLayout(itemsPerRow: itemsPerRow, style: .SEPARATED)
                }, configureCustomLayout: { layout in
                    layout.itemsPerRow = itemsPerRow
                    layout.titleSize = 75.0
                })
                .alwaysBounceVertical()
                .animateOnDataRefresh(true)
                .onRotate { newOrientation in
                    if newOrientation.isFlat { return }
                    isPotrait = newOrientation.isPortrait
                }
                .fullScreenCover(item: $chapter) { chapter in
                    ReaderGateWay(readingMode: .PAGED_COMIC, chapterList: [chapter], openTo: chapter, title: chapter.title)
                }
        }

        var AS_SECTION: ASSection<Int> {
            return ASSection(id: 0, data: feed.publications) { publication, _ in
                Button {
                    // TODO: Check if downloaded, if so use download object instead
                    if publication.isStreamable {
                        do {
                            chapter = try publication.toStoredChapter()
                        } catch {
                            ToastManager.shared.display(.error(error))
                        }
                    } else {
                        // Open Download Dialog
                    }
                } label: {
                    Tile(publication: publication)
                }
                .buttonStyle(NeutralButtonStyle())
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
        var request: URLRequest? {
            var headers = HTTPHeaders()

            if let auth = client.authHeader {
                headers.add(name: "Authorization", value: auth)
            }
            return try? URLRequest(url: publication.thumbnailURL ?? "", method: HTTPMethod.get, headers: headers)
        }

        var body: some View {
            GeometryReader { proxy in
                let imageWidth = proxy.size.width
                let imageHeight = imageWidth * 1.5
                VStack(alignment: .leading, spacing: 5) {
                    image.view?
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .frame(width: imageWidth, height: imageHeight)
                        .background(Color.fadedPrimary)
                        .cornerRadius(7)

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(STTHelpers.getComicTitle(from: publication.metadata.title))
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack {
                            if publication.isStreamable {
                                Image(systemName: "dot.radiowaves.up.forward")
                                Spacer()
                            }

                            if let pages = publication.streamLink?.properties["count"] as? String ?? publication.metadata.numberOfPages?.description {
                                Text(pages + " Pages")
                            }
                        }
                        .font(.footnote.weight(.thin))
                    }

                    .frame(alignment: .topLeading)
                }
            }
            .onAppear {
                if let request = request {
                    image.load(.init(urlRequest: request))
                }
            }
            .onDisappear { image.reset() }
        }
    }
}

extension Publication: Identifiable {
    public var id: Int {
        metadata.hashValue
    }

    public var thumbnailURL: String? {
        links.first(withRel: .opdsImageThumbnail)?.href
    }

    public var acquisitionLink: String? {
        links.first(withRel: .opdsAcquisition)?.href
    }

    public var streamLink: R2Shared.Link? {
        links.first(withRel: .init("http://vaemendis.net/opds-pse/stream"))
    }

    public var isStreamable: Bool {
        streamLink != nil
    }

    func toStoredChapter() throws -> StoredChapter {
        guard let link = streamLink, let count = link.properties["count"] as? String, let lastRead = link.properties["lastRead"] as? String else {
            throw OPDSParserError.documentNotFound
        }

        let chapter = StoredChapter()

        chapter.sourceId = STTHelpers.OPDS_CONTENT_ID
        chapter.contentId = link.href
        chapter.chapterId = "\(count)|\(lastRead)"
        chapter._id = UUID().uuidString
        chapter.title = metadata.title
        return chapter
    }
}
