//
//  SearchView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import ASCollectionView
import RealmSwift
import SwiftUI

struct SearchView: View {
    typealias Highlight = DSKCommon.Highlight
    @State private var initial = true
    var initialQuery = ""
    @StateObject private var model = ViewModel()
    @State private var presentHistory = false
    @State private var presentImageSearch = false
    @State var searchTask: Task<Void, Never>?
    var body: some View {
        Group {
            if model.query.isEmpty {
                HistoryView()
                    .transition(.opacity)
            } else {
                if case .loaded = model.state, model.results.isEmpty {
                    NoResultsView()
                        .transition(.opacity)
                } else {
                    if model.state == .loading, model.results.isEmpty {
                        ProgressView()
                            .transition(.opacity)
                    } else {
                        CollectionView()
                            .transition(.opacity)
                            .task {
                                await model.observe()
                            }
                    }
                }
            }
        }
        .animation(.default, value: model.state)
        .environmentObject(model)
        .navigationTitle("Search All")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main).dropFirst()) { val in
            if val.isEmpty {
                model.results.removeAll()
                return
            }
            searchTask?.cancel()
            searchTask = Task {
                await model.makeRequests()
            }
        }
        .onSubmit(of: .search) {
            let request: DSKCommon.DirectoryRequest = .init(query: model.query, page: 1)
            let display = model.query
            Task {
                let actor = await RealmActor()
                await actor.saveSearch(request, sourceId: nil, display: display)
            }
            searchTask?.cancel()
            searchTask = Task {
                await model.makeRequests()
            }
        }
        .task {
            if initialQuery.isEmpty || !initial { return }
            model.query = initialQuery
            await model.makeRequests()
            initial.toggle()
        }
        .animation(.default, value: model.query)
        .hiddenNav(presenting: $presentImageSearch) {
            ImageSearchView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                StatusView
                MenuView
            }
        }
        .onDisappear {
            model.stopObserving()
        }
    }

    var MenuView: some View {
        Menu {
            Button {
                presentImageSearch.toggle()
            } label: {
                Label("Image Search", systemImage: "photo")
            }
            Divider()
            Button(role: .destructive) {
                Task {
                    let actor = await RealmActor()
                    await actor.deleteSearchHistory()
                    await model.loadSearchHistory()
                }
            } label: {
                Label("Clear History", systemImage: "xmark")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    var StatusView: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
                    .transition(.opacity)
            case .loaded:
                if hasEmpty || hasFailing {
                    Menu {
                        if hasEmpty {
                            Text("\(model.incomplete.noResults.count) source(s) with no results")
                        }
                        if hasFailing {
                            Text("\(model.incomplete.failing.count) source(s) failed.")
                        }
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            default:
                EmptyView()
                    .transition(.opacity)
            }
        }
    }

    var hasFailing: Bool {
        !model.incomplete.failing.isEmpty
    }

    var hasEmpty: Bool {
        !model.incomplete.noResults.isEmpty
    }
}

extension SearchView {
    struct NoResultsView: View {
        var body: some View {
            VStack(spacing: 3.5) {
                Text("(─‿‿─)♡")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("no results.")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
            .foregroundColor(.gray)
            .transition(.opacity)
        }
    }
}
