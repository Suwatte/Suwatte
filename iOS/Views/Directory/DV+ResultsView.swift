//
//  DV+ResultsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI
import ASCollectionView


extension DirectoryView {
    struct ResultsView: View {
        var entries: [T]
        var builder: (T) -> C
        
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
                .cacheCells()
                .sectionHeader {
                    GridHeader()
                }
                .sectionFooter {
                    PaginationView()
                }
            }
            
            .layout(createCustomLayout: {
                DynamicGridLayout(header: .estimated(hasHeader ? 44: 0), footer: .estimated(44))
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
            model.resultCount != nil || !model.sortOptions.isEmpty
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
                    Text("\(resultCount) Results")
                }
                Spacer()
                if !model.sortOptions.isEmpty {
                    Button {
                        dialog.toggle()
                    } label: {
                        HStack {
                            Text(title)
                            Image(systemName: "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .disabled(model.sortOptions.isEmpty) // Redundant
                }
            }
            .font(.subheadline.weight(.light))
            .foregroundColor(Color.primary.opacity(0.7))
            .padding(.top)
            .confirmationDialog("Sort Results", isPresented: $dialog, titleVisibility: .visible) {
                ForEach(model.sortOptions, id: \.key) { sorter in
                    Button(sorter.label) {
                        withAnimation {
                            model.request.sortKey = sorter.key
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
        
        var title: String {
            let current = model.request.sortKey
            let label = model.sortOptions.first(where: { $0.key == current })?.label
            return label ?? model.sortOptions.first?.label ?? "Default"
        }
    }

}
// MARK: - Pagination View
extension DirectoryView.ResultsView {
    struct PaginationView: View {
        @EnvironmentObject var model: DirectoryView.ViewModel
        
        var body: some View {
            Group {
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
