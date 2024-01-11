//
//  DV+ResultsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import ASCollectionView
import SwiftUI

extension DirectoryView {
    struct ResultsView: View {
        let entries: [DSKCommon.Highlight]
        let builder: (DSKCommon.Highlight) -> C

        @State var presentDialog = false
        @EnvironmentObject var model: ViewModel

        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6

        var body: some View {
            ASCollectionView {
                ASCollectionViewSection(id: 0, data: entries, dataID: \.hashValue) { data, state in
                    builder(data)
                        .task {
                            if state.isLastInSection {
                                await model.paginate()
                            }
                        }
                }
                .sectionHeader {
                    ZStack {
                        if hasHeader {
                            GridHeader()
                        } else {
                            EmptyView()
                        }
                    }
                }
                .sectionFooter {
                    PaginationView()
                }
            }
            .layout(createCustomLayout: {
                DynamicGridLayout(header: hasHeader ? .estimated(5) : .absolute(1), footer: .estimated(44))
            }, configureCustomLayout: { layout in
                layout.invalidateLayout()
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            // Triggers View Rebuild which trigger collectionview layout invalidaiton
            .onChange(of: PortraitPerRow, perform: { _ in })
            .onChange(of: LSPerRow, perform: { _ in })
            .onChange(of: style, perform: { _ in })
        }

        var hasHeader: Bool {
            model.resultCount != nil || model.showButton
        }
    }
}

// MARK: - Header View

extension DirectoryView.ResultsView {
    struct GridHeader: View {
        @EnvironmentObject var model: DirectoryView.ViewModel
        @State var dialog = false
        var body: some View {
            HStack {
                if let resultCount = model.resultCount {
                    Text("\(resultCount) Titles")
                        .foregroundColor(Color.primary.opacity(0.7))
                }
                Spacer()
                if model.showButton {
                    Menu {
                        Section {
                            ForEach(model.lists) { list in
                                Button(list.title) {
                                    model.selectList(list)
                                }
                            }
                        } header: {
                            Text("Lists")
                        }
                        if !model.configSort.options.isEmpty && !model.lists.isEmpty {
                            Divider()
                        }
                        if !model.configSort.options.isEmpty {
                            Section {
                                ForEach(model.configSort.options) { option in
                                    Button(option.title) {
                                        withAnimation {
                                            model.selectSortOption(option)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("Sort")
                            }
                        }

                    } label: {
                        HStack {
                            Text(title)
                            if model.request.listId != nil {
                                Image(systemName: "list.clipboard")
                            } else {
                                Image(systemName: model.request.sort?.ascending ?? false ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.accentColor)
                    .multilineTextAlignment(.trailing)
                }
            }
            .font(.footnote.weight(.light))
            .confirmationDialog("Sort Options", isPresented: $dialog, titleVisibility: .visible) {}
        }

        var title: String {
            if let listID = model.request.listId {
                return model.lists.first(where: { $0.id == listID })?.title ?? "Unknown List"
            }
            let current = model.request.sort?.id
            let label = model.configSort.options.first(where: { $0.id == current })?.title
            return label ?? model.configSort.options.first(where: { $0.id == model.configSort.default?.id })?.title ?? model.configSort.options.first?.title ?? "Default"
        }
    }
}

// MARK: - Pagination View

extension DirectoryView.ResultsView {
    struct PaginationView: View {
        @EnvironmentObject var model: DirectoryView.ViewModel

        var body: some View {
            ZStack {
                switch model.pagination {
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
    }
}
