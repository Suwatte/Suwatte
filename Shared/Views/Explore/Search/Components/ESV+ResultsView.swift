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
import SwiftUIBackports

extension ExploreView.SearchView {
    struct ResultsView: View {
        typealias Highlight = DaisukeEngine.Structs.Highlight
        var entries: [Highlight]
        @State var presentSortDialog = false
        @EnvironmentObject var model: ViewModel
        @EnvironmentObject var source: DaisukeContentSource

        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @State var selection: HighlightIndentier?
        var body: some View {
            ASCollectionView {
                ASCollectionViewSection(id: 0,
                                        data: entries) { data, state in
                    let isInLibrary = DataManager.shared.contentInLibrary(s: source.id, c: data.contentId)
                    let isSavedForLater = DataManager.shared.contentSavedForLater(s: source.id, c: data.contentId)

                    ContentCell(data: data, inLibrary: isInLibrary, readLater: isSavedForLater)
                        .onTapGesture(perform: {
                            selection = (source.id, data)
                        })
                        .task {
                            if state.isLastInSection {
                                await model.paginate()
                            }
                    }
                }
                .cacheCells()
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
                DynamicGridLayout(header: .estimated(30), footer: .estimated(44))
            }, configureCustomLayout: { layout in
                layout.invalidateLayout()
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            .modifier(InteractableContainer(selection: $selection))
            .onChange(of: style, perform: { _ in })
            .onChange(of: PortraitPerRow, perform: { _ in })
            .onChange(of: LSPerRow, perform: { _ in })
            .confirmationDialog("Sort", isPresented: $presentSortDialog) {
                ForEach(model.sorters) { sorter in
                    Button(sorter.label) {
                        withAnimation {
                            model.request.sort = sorter.id
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
    }
}

extension ExploreView.SearchView.ResultsView {
    struct ContentCell: View {
        @EnvironmentObject var source: DaisukeContentSource
        let data: DSKCommon.Highlight
        @State var inLibrary: Bool
        @State var readLater: Bool
        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: data)
                if inLibrary || readLater {
                    ColoredBadge(color: inLibrary ? .accentColor : .yellow)
                }
            }
            .contextMenu {
                Button {
                    if readLater {
                        DataManager.shared.removeFromReadLater(source.id, content: data.contentId)
                    } else {
                        DataManager.shared.addToReadLater(source.id, data.contentId)
                    }
                    readLater.toggle()
                } label: {
                    Label( readLater ? "Remove from Read Later" : "Add to Read Later", systemImage: readLater ? "bookmark.slash" : "bookmark")
                }
            }
        }
    }
}

extension ExploreView.SearchView.ResultsView {
    var SORT_TITLE: String {
        if let sortId = model.request.sort, let sorter = model.sorters.first(where: { $0.id == sortId }) {
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
            } label: {
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
            .padding(.all)
        case let .ERROR(error):
            ErrorView(error: error) {
                Task {
                    await model.paginate()
                }
            }
        }
    }
}
