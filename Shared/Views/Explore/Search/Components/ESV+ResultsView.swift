//
//  ESV+ResultsView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import ASCollectionView
import Kingfisher
import RealmSwift
import SwiftUI

extension ExploreView.SearchView {
    struct ResultsView: View {
        typealias Highlight = DaisukeEngine.Structs.Highlight
        var entries: [Highlight]
        @State var presentSortDialog = false
        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        @ObservedResults(LibraryEntry.self) var library
        @ObservedResults(ReadLater.self) var forLaterLibrary
        @EnvironmentObject var model: ViewModel
        @EnvironmentObject var source: DaisukeContentSource

        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6

        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait
        @State var selection: HighlightIndentier?
        var body: some View {
            ASCollectionView {
                ASCollectionViewSection(id: 0,
                                        data: entries,
                                        contextMenuProvider: contextMenuProvider) { data, state in
                    let isInLibrary = inLibrary(data)
                    let isSavedForLater = savedForLater(data)

                    ZStack(alignment: .topTrailing) {
                        DefaultTile(entry: data)
                        if isInLibrary || isSavedForLater {
                            ColoredBadge(color: isInLibrary ? .accentColor : .yellow)
                        }
                    }
                    .onTapGesture(perform: {
                        selection = (source.id, data)
                    })
                    .task {
                        if state.isLastInSection {
                            await model.paginate()
                        }
                    }
                }
                .sectionHeader {
                    Group {
                        if model.resultCount != nil || !model.sorters.isEmpty {
                            Header
                        } else { EmptyView() }
                    }
                }
                .sectionFooter {
                    PaginationView
                }
            }

            .layout(createCustomLayout: {
                SuwatteDefaultGridLayout(itemsPerRow: itemsPerRow, style: style)
            }, configureCustomLayout: { layout in
                layout.itemsPerRow = itemsPerRow
                layout.itemStyle = style
                layout.headerReferenceSize = .init(width: layout.collectionView?.bounds.width ?? 0, height: model.sorters.isEmpty ? 0 : 30)

                var height = 35
                switch model.paginationStatus {
                case .ERROR: height = 400
                default: break
                }
                layout.footerReferenceSize = .init(width: layout.collectionView?.bounds.width ?? 0, height: CGFloat(height))
            })
            .alwaysBounceVertical()
            .onRotate { newOrientation in
                if newOrientation.isFlat { return }
                isPotrait = newOrientation.isPortrait
            }
            .animation(.default, value: library)
            .animation(.default, value: forLaterLibrary)
            .modifier(InteractableContainer(selection: $selection))
        }
    }
}

extension ExploreView.SearchView.ResultsView {
    func contextMenuProvider(int _: Int, content: Highlight) -> UIContextMenuConfiguration? {
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil)
            { _ -> UIMenu? in

                let inLater = savedForLater(content)
                let action = UIAction(title: inLater ? "Remove from Read Later" : "Add to Read Later", image: UIImage(systemName: inLater ? "bookmark.slash" : "bookmark")) {
                    _ in
                    if inLater {
                        DataManager.shared.removeFromReadLater(source.id, content: content.id)
                    } else {
                        DataManager.shared.addToReadLater(source.id, content.id)
                    }
                }

                return .init(title: "", children: [action])
            }
        return configuration
    }

    func inLibrary(_ entry: Highlight) -> Bool {
        library
            .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id })
    }

    func savedForLater(_ entry: Highlight) -> Bool {
        forLaterLibrary
            .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id })
    }
}

extension ExploreView.SearchView.ResultsView {
    var SORT_TITLE: String {
        if let sorter = model.request.sort {
            return sorter.label
        }
        return "Order"
    }

    var Header: some View {
        HStack {
            if let resultCount = model.resultCount {
                Text("\(resultCount) Results")
            }
            Spacer()
            Button {
                presentSortDialog.toggle()
            }
        label: {
                HStack {
                    Text(SORT_TITLE)
                    Image(systemName: "chevron.down")
                }
            }
            .buttonStyle(.plain)
            .multilineTextAlignment(.trailing)
        }
        .font(.subheadline.weight(.light))
        .foregroundColor(Color.primary.opacity(0.7))
        .padding(.horizontal)
        .confirmationDialog("Sort", isPresented: $presentSortDialog) {
            ForEach(model.sorters) { sorter in
                Button(sorter.label) {
                    withAnimation {
                        model.request.sort = sorter
                        model.request.page = 1
                        Task {
                            await model.makeRequest()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    var PaginationView: some View {
        switch model.paginationStatus {
        case .IDLE: EmptyView()
        case .LOADING: ProgressView()
        case .END: Text("End Reached")
            .font(.caption)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(.gray)
        case let .ERROR(error):
            ErrorView(error: error) {
                Task {
                    await model.paginate()
                }
            }
        }
    }
}
