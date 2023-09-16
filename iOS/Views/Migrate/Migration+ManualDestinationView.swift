//
//  Migration+ManualDestinationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-28.
//

import SwiftUI

struct MigrationManualDestinationView: View {
    let content: TaggedHighlight
    @StateObject var searchModel: SearchView.ViewModel

    @EnvironmentObject private var migrationModel: MigrationController
    @State var searchTask: Task<Void, Never>? = nil
    var body: some View {
        ZStack {
            if !searchModel.results.isEmpty {
                List {
                    ForEach(searchModel.results, id: \.sourceID) { group in
                        MigrationManualDestinationResultGroupCell(result: group, content: content)
                            .listRowInsets(.init(top: 5, leading: 0, bottom: 20, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 0))
            } else {
                Text("No Results.")
            }
        }
        .animation(.default, value: searchModel.results)
        .navigationBarTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchModel.query, placement: .navigationBarDrawer(displayMode: .always))
        .onReceive(searchModel.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main)) { val in
            if val.isEmpty {
                searchModel.results.removeAll()
                return
            }
            searchTask?.cancel()
            searchTask = Task {
                await searchModel.makeRequests()
            }
        }
        .onAppear {
            searchModel.query = content.title
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if searchModel.incomplete.hasIncomplete {
                    Menu {
                        Text("\(searchModel.incomplete.failing.count) failing")
                        Text("\(searchModel.incomplete.noResults.count) with no results")
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
    }
}

struct MigrationManualDestinationResultGroupCell: View {
    let result: SearchView.ResultGroup
    let content: TaggedHighlight
    @AppStorage(STTKeys.TileStyle) private var tileStyle = TileStyle.SEPARATED
    @EnvironmentObject private var model: MigrationController

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(result.result.results) { highlight in
                        DefaultTile(entry: highlight)
                            .frame(width: 150)
                            .onTapGesture {
                                model.operations[content.id] = .found(.init(from: highlight,
                                                                            with: result.sourceID))
                                model.selectedToSearch = nil
                            }
                    }
                }
                .frame(height: CELL_HEIGHT)
                .padding(.leading)
            }

        } header: {
            Text(result.sourceName)
                .padding(.horizontal)
        }
    }

    private var CELL_HEIGHT: CGFloat {
        (150 * 1.5) + (tileStyle == .SEPARATED ? 50 : 0)
    }
}
