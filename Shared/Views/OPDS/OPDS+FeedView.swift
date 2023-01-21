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
import SwiftUIBackports
import RealmSwift

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
        @StateObject var manager: LocalContentManager = .shared
        @State var chapter: StoredChapter?
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
                    ReaderGateWay(readingMode: .PAGED_COMIC, chapterList: [chapter], openTo: chapter, title: chapter.title)
                }
                .animation(.default, value: chapter)
        }

        var AS_SECTION: ASSection<Int> {
            return ASSection(id: 0, data: feed.publications) { publication, _ in
                ZStack(alignment: .topTrailing) {
                    Tile(publication: publication, chapter: $chapter)
                    if let url = publication.acquisitionLink.flatMap({ URL(string: $0) }) {
                        if let download = manager.downloads.first(where: { $0.url == url }) {
                            TileOverlay(download: download)
                        } else if LocalContentManager.shared.hasFile(fileName: url.lastPathComponent) {
                            ColoredBadge(color: accentColor)
                        }
                    }
                }
            }
        }
        
        struct TileOverlay: View {
            @ObservedObject var download: LocalContentManager.DownloadObject
            var body: some View {
                ZStack(alignment: .topTrailing) {
                    Group {
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
        @Binding var chapter: StoredChapter?
        
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
                    Group {
                        if let view = image.view {
                            view
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .transition(.opacity)
                        } else {
                            Color.gray.opacity(0.25)
                                .shimmering()
                                .transition(.opacity)

                        }
                    }
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
                if let request = request {
                    image.load(.init(urlRequest: request))
                }
            }
            .onDisappear { image.reset() }
            .animation(.default, value: image.view)
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
                        if LocalContentManager.shared.hasFile(fileName: link.lastPathComponent) {
                            Button("Read") {
                                let path = LocalContentManager.shared.directory.appendingPathComponent(link.lastPathComponent)
                                let book = LocalContentManager.shared.idHash.values.first(where: { $0.url == path })
                                guard let book else {
                                    ToastManager.shared.info("Book Not Found")
                                    return
                                }
                                chapter = LocalContentManager.shared.generateStored(for: book)
                            }
                        } else {
                            Button("Download") {
                                let download = LocalContentManager.DownloadObject(url: link, title: publication.metadata.title, cover: publication.thumbnailURL ?? "")
                                download.opdsClient = client
                                LocalContentManager.shared.addToQueue(download)
                            }
                        }
                    }
                    if publication.isStreamable && !publication.isProtected {
                        Button("Stream") {
                            do {
                                chapter = try publication.toStoredChapter()
                            } catch {
                                ToastManager.shared.error(error)
                            }
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
        chapter.contentId = metadata.identifier ?? link.href
        chapter.chapterId = link.href
        chapter._id = ContentIdentifier(contentId: chapter.contentId, sourceId: chapter.sourceId).id
        chapter.title = metadata.title
        chapter.thumbnail = thumbnailURL
        let d = Map<String, String>()
        d.setValue(count, forKey: "opds_page_count")
        d.setValue(lastRead, forKey: "opds_last_read")
        chapter.metadata = d
        return chapter
    }
}

