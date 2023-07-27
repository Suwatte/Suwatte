//
//  ReadLaterView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//

import ASCollectionView
import RealmSwift
import SwiftUI

extension LibraryView {
    struct ReadLaterView: View {
        typealias Highlight = DaisukeEngine.Structs.Highlight
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @StateObject var model = ViewModel()
        var body: some View {
            
            ZStack {
                CollectionView()
                    .opacity(!model.readLater.isEmpty && model.initialFetchComplete ? 1 : 0)
                
                NoResultsView()
                    .opacity(model.readLater.isEmpty && model.initialFetchComplete ? 1 : 0)

                ProgressView()
                    .opacity(model.readLater.isEmpty && !model.initialFetchComplete ? 1 : 0)
            
            }
            .animation(.default, value: model.library)
            .animation(.default, value: model.readLater)
            .navigationTitle("Saved For Later")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                model.observe()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort Titles", selection: $model.sort) {
                            ForEach(ContentSort.allCases, id: \.rawValue) { val in
                                Text(val.description)
                                    .tag(val)
                            }
                        }
                        .pickerStyle(.menu)
                        Button {
                            model.ascending.toggle()
                        } label: {
                            Label("Order", systemImage: model.ascending ? "chevron.down" : "chevron.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Titles")
            .animation(.default, value: model.query)
            .modifier(InteractableContainer(selection: $model.selection))
            .environmentObject(model)
        }
    }
}

extension LibraryView.ReadLaterView {
    struct NoResultsView: View {
        var body: some View {
            VStack(spacing: 3.5) {
                Text("三 ┏ ( ˘ω˘ )┛")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("no titles to show")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
            .foregroundColor(.gray)
        }
    }
}

extension LibraryView.ReadLaterView {
    enum ContentSort: Int, CaseIterable {
        case dateAdded, title

        var description: String {
            switch self {
            case .dateAdded:
                return "Date Added"
            case .title:
                return "Title"
            }
        }

        var KeyPath: String {
            switch self {
            case .dateAdded:
                return "dateAdded"
            case .title:
                return "content.title"
            }
        }
    }
}
