//
//  BookmarksView+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import ASCollectionView
import NukeUI
import SwiftUI

extension BookmarksView {
    struct CollectionsView: View {
        let results: [UpdatedBookmark]
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @State var selection: String?
        var body: some View {
            ASCollectionView {
                ASCollectionViewSection(id: 0,
                                        data: results,
                                        dataID: \.hashValue)
                { data, _ in
                    Cell(data: data)
                        .onTapGesture {
                            selection = data.id
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    let actor = await RealmActor.shared()
                                    await actor.removeBookmark(data.id)
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            Divider()

                            Button {
                                selection = data.id
                            } label: {
                                Label("Enlarge", systemImage: "eye")
                            }

                            Button {
                                StateManager.shared.open(bookmark: data)
                            } label: {
                                Label("Continue Reading", systemImage: "play")
                            }
                        }
                }
                .sectionHeader {
                    EmptyView()
                }
                .sectionFooter {
                    EmptyView()
                }
            }

            .layout(createCustomLayout: {
                DynamicGridLayout(header: .absolute(1), footer: .absolute(1), 60)
            }, configureCustomLayout: { layout in
                layout.invalidateLayout()
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            // Triggers View Rebuild which trigger collectionview layout invalidation
            .onChange(of: PortraitPerRow, perform: { _ in })
            .onChange(of: LSPerRow, perform: { _ in })
            .onChange(of: style, perform: { _ in })
            .fullScreenCover(item: $selection) { id in
                PagerView(pages: Binding.constant(results), selection: id)
            }
        }
    }
}

private typealias CollectionsView = BookmarksView.CollectionsView

extension CollectionsView {
    struct Cell: View {
        let data: UpdatedBookmark
        @StateObject var loader = FetchImage()
        var body: some View {
            GeometryReader { proxy in
                let size = CGSize(width: proxy.size.width, height: proxy.size.width * 1.5)
                VStack(alignment: .leading) {
                    ImageView()
                        .frame(width: size.width, height: size.height)

                    TitleView()
                        .frame(height: 44)
                }
                .task {
                    load(size)
                }
            }
        }

        // Views
        @ViewBuilder
        func ImageView() -> some View {
            if let image = loader.image {
                image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(5)
            } else {
                Color.clear
            }
        }

        func TitleView() -> some View {
            VStack(alignment: .leading) {
                Text(chapter.displayName)
                    .font(.headline)
                Text("Page \(data.page)")
                    .font(.subheadline)
                Text(data.dateAdded.timeAgo())
                    .font(.caption2)
            }
        }

        // Methods
        var chapter: ChapterReference {
            data.chapter!
        }

        func load(_ size: CGSize) {
            if loader.image != nil { return }
            loader.priority = .normal
            loader.transaction = .init(animation: .easeInOut(duration: 0.25))
            loader.processors = [NukeDownsampleProcessor(size: size, scale: UIScreen.main.scale)]

            guard let imageData = data.asset?.storedData() else { return }
            let request = ImageRequest(id: "bookmark::\(data.id)") {
                imageData
            }
            loader.load(request)
        }
    }
}
